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
SOCKFILE_LIST="${SOCKFILE}"

# start global rump server
./rumpdyn/bin/rump_server -lrumpvfs -lrumpnet -lrumpnet_net -lrumpnet_netinet -lrumpnet_netinet6 -lrumpnet_shmif $SOCKFILE
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
./rumprun ifconfig | grep lo0 > /dev/null
}
definetest Test_ifconfig

Test_sysctl()
{
./rumprun sysctl kern.hostname | grep 'kern.hostname = rump-' > /dev/null
}
definetest Test_sysctl

Test_df()
{
./rumprun df | grep rumpfs > /dev/null
}
definetest Test_df

Test_cat()
{
./rumprun cat /dev/null > /dev/null
}
definetest Test_cat

Test_ping()
{
./rumprun ping -o 127.0.0.1 | grep '64 bytes from 127.0.0.1: icmp_seq=0' > /dev/null
}
definetest Test_ping

Test_ping6()
{
./rumprun ping6 -c 1 ::1 | grep '16 bytes from ::1, icmp_seq=0' > /dev/null
}
definetest Test_ping6

Test_directories()
{
./rumpremote mkdir /tmp > /dev/null
./rumpremote ls / | grep tmp > /dev/null
./rumpremote rmdir /tmp > /dev/null
./rumpremote ls / | grep -v tmp > /dev/null
}
definetest Test_directories

Test_ktrace()
{
# no kdump support yet so does not test output is sane
./rumpremote ktrace ./rumpremote ls > /dev/null
./rumpremote ls / | grep ktrace.out > /dev/null
./rumpremote rm ktrace.out > /dev/null
}
definetest Test_ktrace

Test_shmif()
{
rm -f test_busmem
./rumpremote ifconfig shmif0 create > /dev/null
./rumpremote ifconfig shmif0 linkstr test_busmem > /dev/null
./rumpremote ifconfig shmif0 inet 1.2.3.4 netmask 0xffffff00 > /dev/null
./rumpremote ifconfig shmif0 | grep 'shmif0: flags=8043<UP,BROADCAST,RUNNING,MULTICAST> mtu 1500' > /dev/null
}
definetest Test_shmif

Test_npf()
{
# create servers
rm -f test_busmem
./rumpdyn/bin/rump_server -lrumpnet_shmif -lrumpnet_netinet -lrumpnet_net -lrumpnet $SOCKFILE1
./rumpdyn/bin/rump_server -lrumpnet_shmif -lrumpnet_netinet -lrumpnet_net -lrumpnet -lrumpnet_npf -lrumpdev_bpf -lrumpdev -lrumpvfs $SOCKFILE2

# configure network
export RUMP_SERVER="$SOCKFILE1"
./rumpremote ifconfig shmif0 create
./rumpremote ifconfig shmif0 linkstr test_busmem
./rumpremote ifconfig shmif0 inet 1.2.3.1

export RUMP_SERVER="$SOCKFILE2"
./rumpremote ifconfig shmif0 create
./rumpremote ifconfig shmif0 linkstr test_busmem
./rumpremote ifconfig shmif0 inet 1.2.3.2

./rumpremote ping -c 1 1.2.3.1 > /dev/null

echo 'group default {
        ruleset "test-set"
        pass all
}' | ./rumpremote dd of=/npf.conf 2> /dev/null
./rumpremote npfctl reload /npf.conf
./rumpremote npfctl rule "test-set" add block proto icmp from 1.2.3.1 > /dev/null

./rumpremote ping -oq 1.2.3.1 | grep '1 packets received' > /dev/null

./rumpremote npfctl start
./rumpremote ping -oq -w 2 1.2.3.1 | grep '0 packets received' > /dev/null

./rumpremote npfctl stop
./rumpremote ping -oq -w 2 1.2.3.1 | grep '1 packets received' > /dev/null
}
definetest Test_npf ${SOCKFILE1} ${SOCKFILE2}

Test_cgd()
{
export RUMP_SERVER="${SOCKFILE_CGD}"
rm -f test_disk1
./rumpdyn/bin/rump_server -lrumpfs_ffs -lrumpdev -lrumpdev_disk -lrumpvfs -lrumpdev_cgd -lrumpkern_crypto -lrumpdev_rnd -d key=/disk1,hostpath=test_disk1,size=$((1000*512)) "${RUMP_SERVER}"

./rumpremote cgdconfig -g -o /cgd.conf -k storedkey aes-cbc 192
./rumpremote cgdconfig cgd0 /disk1 /cgd.conf
./rumpremote newfs cgd0a > /dev/null

./rumpremote mkdir /mnt
./rumpremote mount_ffs /dev/cgd0a /mnt
./rumpremote mount | grep -q cgd0a
}
definetest Test_cgd ${SOCKFILE_CGD}

# actually run the tests
for test in ${TESTS}; do
	runtest ${test}
done

# shutdown
for serv in ${SOCKFILE_LIST}; do
	RUMP_SERVER=${serv} ./rumpremote halt
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
