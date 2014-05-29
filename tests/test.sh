#!/bin/sh

# Initial test script to sanity check

# set up environment
EC=0

SOCKFILE="unix://csock-$$"
SOCKFILE1="unix://csock1-$$"
SOCKFILE2="unix://csock2-$$"
SOCKFILE_CGD="unix://csock2-cgd-$$"
SOCKFILE_RAID="unix://csock-rf-$$"
SOCKFILE_LIST="${SOCKFILE}"

# create file system test image
FSIMG=test.ffs.img
dd of=${FSIMG} bs=1048576 seek=16 count=0 >/dev/null 2>&1

# start global rump server
./rumpdyn/bin/rump_server -lrumpvfs -lrumpfs_kernfs -lrumpfs_ffs -lrumpdev_disk -lrumpdev -lrumpnet -lrumpnet_net -lrumpnet_netinet -lrumpnet_netinet6 -lrumpnet_shmif -d key=/fsimg,hostpath=${FSIMG},size=host -d key=/rfsimg,hostpath=${FSIMG},size=host,type=chr -r 2m $SOCKFILE

export RUMP_SERVER="$SOCKFILE"
. ./rumpremote.sh

TESTS=''
definetest ()
{

	test=$1
	shift
	TESTS="${TESTS} ${test}"
	[ $# -gt 0 ] && SOCKFILE_LIST="${SOCKFILE_LIST} $*"
}

runtest ()
{

	printf "$1 ... "
	( set -e ; $1 )
	if [ $? -ne 0 ]
	then 
		echo "ERROR"
		EC=$((${EC} + 1))
	else
		echo "passed"
	fi 
}

# tests

Test_ifconfig()
{

	ifconfig | grep lo0 > /dev/null
}
definetest Test_ifconfig

Test_sysctl()
{

	sysctl kern.hostname | grep 'kern.hostname = rump-' > /dev/null
}
definetest Test_sysctl

Test_df()
{

	df | grep rumpfs > /dev/null
}
definetest Test_df

Test_cat()
{

	cat /dev/null > /dev/null
}
definetest Test_cat

Test_ping()
{

	ping -o 127.0.0.1 \
	    | grep '64 bytes from 127.0.0.1: icmp_seq=0' > /dev/null
}
definetest Test_ping

Test_ping6()
{

	ping6 -c 1 ::1 | grep '16 bytes from ::1, icmp_seq=0' > /dev/null
}
definetest Test_ping6

Test_directories()
{

	dirname=definitely_nonexisting_directory
	mkdir /${dirname} > /dev/null
	ls / | grep ${dirname} > /dev/null
	rmdir /${dirname} > /dev/null
	ls / | grep -v ${dirname} > /dev/null
}
definetest Test_directories

Test_ktrace()
{

	# no kdump support yet so does not test output is sane
	ktrace ./bin/ls > /dev/null
	ls / | grep ktrace.out > /dev/null
	rm ktrace.out > /dev/null
}
definetest Test_ktrace

Test_shmif()
{
	BM="test_busmem-$$"
	ifconfig shmif0 create > /dev/null
	ifconfig shmif0 linkstr $BM > /dev/null
	ifconfig shmif0 inet 1.2.3.4 netmask 0xffffff00 > /dev/null
	ifconfig shmif0 \
	   | grep 'shmif0: flags=8043<UP,BROADCAST,RUNNING,MULTICAST> mtu 1500'\
	     > /dev/null
	rumpremote_hostcmd rm $BM
}
definetest Test_shmif

Test_ffs()
{

	newfs /rfsimg > /dev/null
	mkdir /mnt
	mount_ffs /fsimg /mnt >/dev/null
	cat /dev/zero | dd of=/mnt/file 2>&1 | grep -q 'No space left on device'
	umount /mnt
}
definetest Test_ffs

Test_npf()
{
	# create servers
	BM="test_busmem2-$$"
	./rumpdyn/bin/rump_server -lrumpnet_shmif -lrumpnet_netinet -lrumpnet_net -lrumpnet $SOCKFILE1
	./rumpdyn/bin/rump_server -lrumpnet_shmif -lrumpnet_netinet -lrumpnet_net -lrumpnet -lrumpnet_npf -lrumpdev_bpf -lrumpdev -lrumpvfs $SOCKFILE2

	# configure network
	export RUMP_SERVER="$SOCKFILE1"
	ifconfig shmif0 create
	ifconfig shmif0 linkstr $BM
	ifconfig shmif0 inet 1.2.3.1

	export RUMP_SERVER="$SOCKFILE2"
	ifconfig shmif0 create
	ifconfig shmif0 linkstr $BM
	ifconfig shmif0 inet 1.2.3.2

	ping -c 1 1.2.3.1 > /dev/null

	echo 'group default {
		ruleset "test-set"
		pass all
	}' | dd of=/npf.conf 2> /dev/null
	npfctl reload /npf.conf
	npfctl rule "test-set" add block proto icmp from 1.2.3.1 > /dev/null

	ping -oq 1.2.3.1 | grep '1 packets received' > /dev/null

	npfctl start
	ping -oq -w 2 1.2.3.1 | grep '0 packets received' > /dev/null

	npfctl stop
	ping -oq -w 2 1.2.3.1 | grep '1 packets received' > /dev/null
	rumpremote_hostcmd rm $BM
}
definetest Test_npf ${SOCKFILE1} ${SOCKFILE2}

Test_cgd()
{
	export RUMP_SERVER="${SOCKFILE_CGD}"
	DISK="test_disk-$$"
	./rumpdyn/bin/rump_server -lrumpfs_ffs -lrumpdev -lrumpdev_disk -lrumpvfs -lrumpdev_cgd -lrumpkern_crypto -lrumpdev_rnd -d "key=/disk1,hostpath=$DISK,size=$((1000*512))" "${RUMP_SERVER}"

	cgdconfig -g -o /cgd.conf -k storedkey aes-cbc 192
	cgdconfig cgd0 /disk1 /cgd.conf
	newfs cgd0a > /dev/null

	mkdir /mnt
	mount_ffs /dev/cgd0a /mnt
	mount | grep -q cgd0a
	rumpremote_hostcmd rm $DISK
}
definetest Test_cgd ${SOCKFILE_CGD}

Test_raidframe()
{
	D1="disk1-$$"
	D2="disk2-$$"
	RC="raid.conf-$$"
	echo "START array
1 2 0

START disks
/disk1
/disk2

START layout
32 1 1 0

START queue
fifo 100" > ${RC}
	./rumpdyn/bin/rump_server -lrumpdev -lrumpdev_disk -lrumpvfs -lrumpdev_raidframe -lrumpfs_ffs -d "key=/disk1,hostpath=${D1},size=16777216" -d "key=/disk2,hostpath=${D2},size=16777216" -d "key=/raid.conf,hostpath=${RC},size=host,type=reg" $SOCKFILE_RAID
	export RUMP_SERVER="${SOCKFILE_RAID}"

	# create raid device
	raidctl -C /raid.conf raid0
	raidctl -I 24816 raid0

	ls /dev | grep raid0a > /dev/null

	# make a file system
	newfs raid0a | grep 'super-block backups' > /dev/null

	# check it
	fsck_ffs -f /dev/rraid0a \
	    | grep 'File system is already clean' > /dev/null

	# mount
	mkdir /mnt
	mount_ffs /dev/raid0a /mnt
	mount | grep raid0a > /dev/null

	umount /mnt

	rumpremote_hostcmd rm $D1 $D2 $RC
}
definetest Test_raidframe ${SOCKFILE_RAID}

# actually run the tests
for test in ${TESTS}; do
	runtest ${test}
done

# shutdown
for serv in ${SOCKFILE_LIST}; do
	RUMP_SERVER=${serv} halt
done
rumpremote_hostcmd rm ${FSIMG}

# show if passed

if [ $EC -ne 0 ]
then
	echo "FAIL: $EC tests failed"
	exit 1
else
	echo "PASSED"
	exit 0
fi
