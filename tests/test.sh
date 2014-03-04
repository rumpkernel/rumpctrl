#!/bin/sh

# Initial test script to sanity check

# set up environment
export LD_LIBRARY_PATH=.:rumpdyn/lib
export LD_DYNAMIC_WEAK=1
EC=0

SOCKFILE="unix://csock-$$"
SOCKFILE1="unix://csock1-$$"
SOCKFILE2="unix://csock2-$$"

# start global rump server
./rumpdyn/bin/rump_server -lrumpvfs -lrumpnet -lrumpnet_net -lrumpnet_netinet -lrumpnet_netinet6 -lrumpnet_shmif $SOCKFILE
export RUMP_SERVER="$SOCKFILE"

TESTS=''
definetest ()
{

	TESTS="${TESTS} $*"
}

runtest ()
{

	( set -e ; $1 )
	if [ $? -ne 0 ]
	then 
		echo "ERROR $1"
		EC=$((${EC} + 1))
	fi 
}

# tests

Test_ifconfig()
{
echo "Test ifconfig"
./rumprun ifconfig | grep lo0 > /dev/null
}
definetest Test_ifconfig

Test_sysctl()
{
echo "Test sysctl"
./rumprun sysctl kern.hostname | grep 'kern.hostname = rump-' > /dev/null
}
definetest Test_sysctl

Test_df()
{
echo "Test df"
./rumprun df | grep rumpfs > /dev/null
}
definetest Test_df

Test_cat()
{
echo "Test cat"
./rumprun cat /dev/null > /dev/null
}
definetest Test_cat

Test_ping()
{
echo "Test ping"
./rumprun ping -o 127.0.0.1 | grep '64 bytes from 127.0.0.1: icmp_seq=0' > /dev/null
}
definetest Test_ping

Test_ping6()
{
echo "Test ping6"
./rumprun ping6 -c 1 ::1 | grep '16 bytes from ::1, icmp_seq=0' > /dev/null
}
definetest Test_ping6

Test_directories()
{
echo "Test directories"
./rumpremote mkdir /tmp > /dev/null
./rumpremote ls / | grep tmp > /dev/null
./rumpremote rmdir /tmp > /dev/null
./rumpremote ls / | grep -v tmp > /dev/null
}
definetest Test_directories

Test_ktrace()
{
echo "Test ktrace"
# no kdump support yet so does not test output is sane
./rumpremote ktrace ./rumpremote ls > /dev/null
./rumpremote ls / | grep kdump > /dev/null
./rumpremote rm kdump > /dev/null
}
definetest Test_ktrace

Test_shmif()
{
echo "Test shmif"
rm -f test_busmem
./rumpremote ifconfig shmif0 create > /dev/null
./rumpremote ifconfig shmif0 linkstr test_busmem > /dev/null
./rumpremote ifconfig shmif0 inet 1.2.3.4 netmask 0xffffff00 > /dev/null
./rumpremote ifconfig shmif0 | grep 'shmif0: flags=8043<UP,BROADCAST,RUNNING,MULTICAST> mtu 1500' > /dev/null
}
definetest Test_shmif

# TODO does not test for failures properly!
Test_npf()
{
echo "Test npf"
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

./rumpremote ping -c 1 1.2.3.1

cat tests/npf.conf | ./rumpremote dd of=/npf.conf
./rumpremote npfctl reload /npf.conf
./rumpremote npfctl rule "test-set" add block proto icmp from 1.2.3.1

./rumpremote ping -oq 1.2.3.1

./rumpremote npfctl start
./rumpremote ping -oq -w 2 1.2.3.1

./rumpremote npfctl stop
./rumpremote ping -oq -w 2 1.2.3.1
}
definetest Test_npf

# actually run the tests
for test in ${TESTS}; do
	runtest ${test}
done

# shutdown
for serv in ${SOCKFILE} ${SOCKFILE1} ${SOCKFILE2}; do
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
