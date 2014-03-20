#!/bin/sh

# Initial test script to sanity check

# set up environment
export LD_LIBRARY_PATH=.:rumpdyn/lib
export LD_DYNAMIC_WEAK=1
EC=0

SOCKFILE="unix://csock-$$"
SOCKFILE1="unix://csock1-$$"
SOCKFILE2="unix://csock2-$$"
SOCKFILE_CGD="unix://csock2-cgd-$$"
SOCKFILE_RAID="unix://csock-rf-$$"
SOCKFILE_LIST="${SOCKFILE}"

# start global rump server
./rumpdyn/bin/rump_server -lrumpvfs -lrumpfs_kernfs -lrumpdev -lrumpnet -lrumpnet_net -lrumpnet_netinet -lrumpnet_netinet6 -lrumpnet_shmif -lrumpkern_time $SOCKFILE

export RUMP_SERVER="$SOCKFILE"

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
./bin/ifconfig | grep lo0 > /dev/null
}
definetest Test_ifconfig

Test_sysctl()
{
./bin/sysctl kern.hostname | grep 'kern.hostname = rump-' > /dev/null
}
definetest Test_sysctl

Test_df()
{
./bin/df | grep rumpfs > /dev/null
}
definetest Test_df

Test_cat()
{
./bin/cat /dev/null > /dev/null
}
definetest Test_cat

Test_ping()
{
./bin/ping -o 127.0.0.1 | grep '64 bytes from 127.0.0.1: icmp_seq=0' > /dev/null
}
definetest Test_ping

Test_ping6()
{
./bin/ping6 -c 1 ::1 | grep '16 bytes from ::1, icmp_seq=0' > /dev/null
}
definetest Test_ping6

Test_directories()
{
./bin/mkdir /tmp > /dev/null
./bin/ls / | grep tmp > /dev/null
./bin/rmdir /tmp > /dev/null
./bin/ls / | grep -v tmp > /dev/null
}
definetest Test_directories

Test_ktrace()
{
# no kdump support yet so does not test output is sane
./bin/ktrace ./bin/ls > /dev/null
./bin/ls / | grep ktrace.out > /dev/null
./bin/rm ktrace.out > /dev/null
}
definetest Test_ktrace

Test_shmif()
{
BM="test_busmem-$$"
./bin/ifconfig shmif0 create > /dev/null
./bin/ifconfig shmif0 linkstr $BM > /dev/null
./bin/ifconfig shmif0 inet 1.2.3.4 netmask 0xffffff00 > /dev/null
./bin/ifconfig shmif0 | grep 'shmif0: flags=8043<UP,BROADCAST,RUNNING,MULTICAST> mtu 1500' > /dev/null
rm $BM
}
definetest Test_shmif

Test_npf()
{
# create servers
BM="test_busmem2-$$"
./rumpdyn/bin/rump_server -lrumpnet_shmif -lrumpnet_netinet -lrumpnet_net -lrumpnet -lrumpkern_time $SOCKFILE1
./rumpdyn/bin/rump_server -lrumpnet_shmif -lrumpnet_netinet -lrumpnet_net -lrumpnet -lrumpnet_npf -lrumpdev_bpf -lrumpdev -lrumpvfs -lrumpkern_time $SOCKFILE2

# configure network
export RUMP_SERVER="$SOCKFILE1"
./bin/ifconfig shmif0 create
./bin/ifconfig shmif0 linkstr $BM
./bin/ifconfig shmif0 inet 1.2.3.1

export RUMP_SERVER="$SOCKFILE2"
./bin/ifconfig shmif0 create
./bin/ifconfig shmif0 linkstr $BM
./bin/ifconfig shmif0 inet 1.2.3.2

./bin/ping -c 1 1.2.3.1 > /dev/null

echo 'group default {
        ruleset "test-set"
        pass all
}' | ./bin/dd of=/npf.conf 2> /dev/null
./bin/npfctl reload /npf.conf
./bin/npfctl rule "test-set" add block proto icmp from 1.2.3.1 > /dev/null

./bin/ping -oq 1.2.3.1 | grep '1 packets received' > /dev/null

./bin/npfctl start
./bin/ping -oq -w 2 1.2.3.1 | grep '0 packets received' > /dev/null

./bin/npfctl stop
./bin/ping -oq -w 2 1.2.3.1 | grep '1 packets received' > /dev/null
rm $BM
}
definetest Test_npf ${SOCKFILE1} ${SOCKFILE2}

Test_cgd()
{
export RUMP_SERVER="${SOCKFILE_CGD}"
DISK="test_disk-$$"
./rumpdyn/bin/rump_server -lrumpfs_ffs -lrumpdev -lrumpdev_disk -lrumpvfs -lrumpdev_cgd -lrumpkern_crypto -lrumpdev_rnd -lrumpkern_time -d "key=/disk1,hostpath=$DISK,size=$((1000*512))" "${RUMP_SERVER}"

./bin/cgdconfig -g -o /cgd.conf -k storedkey aes-cbc 192
./bin/cgdconfig cgd0 /disk1 /cgd.conf
./bin/newfs cgd0a > /dev/null

./bin/mkdir /mnt
./bin/mount_ffs /dev/cgd0a /mnt
./bin/mount | grep -q cgd0a
rm $DISK
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
./rumpdyn/bin/rump_server -lrumpdev -lrumpdev_disk -lrumpvfs -lrumpdev_raidframe -lrumpfs_ffs -lrumpkern_time -d "key=/disk1,hostpath=${D1},size=16777216" -d "key=/disk2,hostpath=${D2},size=16777216" -d "key=/raid.conf,hostpath=${RC},size=host,type=reg" $SOCKFILE_RAID
export RUMP_SERVER="${SOCKFILE_RAID}"

# create raid device
./bin/raidctl -C /raid.conf raid0
./bin/raidctl -I 24816 raid0

./bin/ls /dev | grep raid0a > /dev/null

# make a file system
./bin/newfs raid0a | grep 'super-block backups' > /dev/null

# check it
./bin/fsck_ffs -f /dev/rraid0a | grep 'File system is already clean' > /dev/null

# mount
./bin/mkdir /mnt
./bin/mount_ffs /dev/raid0a /mnt
./bin/mount | grep raid0a > /dev/null

./bin/umount /mnt

rm $D1 $D2 $RC
}
definetest Test_raidframe ${SOCKFILE_RAID}

# actually run the tests
for test in ${TESTS}; do
	runtest ${test}
done

# shutdown
for serv in ${SOCKFILE_LIST}; do
	RUMP_SERVER=${serv} ./bin/halt
done

# show if passed

if [ $EC -ne 0 ]
then
	echo "FAIL: $EC tests failed"
	exit 1
else
	echo "PASSED"
	exit 0
fi
