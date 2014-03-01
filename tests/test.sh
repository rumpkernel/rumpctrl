#!/bin/sh

# Initial test script to sanity check

# set up environment
export LD_LIBRARY_PATH=.:rumpdyn/lib
export LD_DYNAMIC_WEAK=1
EC=0

# start rump server
SOCKFILE="csock-$$"
./rumpdyn/bin/rump_server -lrumpnet -lrumpnet_net -lrumpnet_netinet -lrumpnet_netinet6 -lrumpnet_shmif unix://$SOCKFILE
export RUMP_SERVER="unix://$SOCKFILE"

# tests

Test_ifconfig()
{
echo "Test ifconfig"
./rumprun ifconfig | grep lo0 > /dev/null
if [ $? -ne 0 ]
then 
	echo "ERROR Test ifconfig"
	EC=`expr $EC + 1`
fi 
}
Test_ifconfig

Test_sysctl()
{
echo "Test sysctl"
./rumprun sysctl kern.hostname | grep 'kern.hostname = rump-' > /dev/null
if [ $? -ne 0 ]
then 
	echo "ERROR Test sysctl"
	EC=`expr $EC + 1`
fi 
}
Test_sysctl

Test_df()
{
echo "Test df"
./rumprun df | grep rumpfs > /dev/null
if [ $? -ne 0 ]
then
	echo "ERROR Test df"
	EC=`expr $EC + 1`
fi
}
Test_df

Test_cat()
{
echo "Test cat"
./rumprun cat /dev/null > /dev/null
if [ $? -ne 0 ]
then
	echo "ERROR Test cat"
	EC=`expr $EC + 1`
fi
}
Test_cat

Test_ping()
{
echo "Test ping"
./rumprun ping -o 127.0.0.1 | grep '64 bytes from 127.0.0.1: icmp_seq=0' > /dev/null
if [ $? -ne 0 ]
then
	echo "ERROR Test ping"
	EC=`expr $EC + 1`
fi
}
Test_ping

Test_ping6()
{
echo "Test ping6"
./rumprun ping6 -c 1 ::1 | grep '16 bytes from ::1, icmp_seq=0' > /dev/null
if [ $? -ne 0 ]
then
	echo "ERROR Test ping6"
	EC=`expr $EC + 1`
fi
}
Test_ping6

Test_shmif()
{
echo "Test shmif"
./rumpremote ifconfig shmif0 create > /dev/null && \
./rumpremote ifconfig shmif0 linkstr busmem > /dev/null && \
./rumpremote ifconfig shmif0 inet 1.2.3.4 netmask 0xffffff00 > /dev/null && \
./rumpremote ifconfig shmif0 | grep 'shmif0: flags=8043<UP,BROADCAST,RUNNING,MULTICAST> mtu 1500' > /dev/null
if [ $? -ne 0 ]
then
	echo "ERROR Test shmif"
	EC=`expr $EC + 1`
fi
}
Test_shmif

# cleanup
rm $SOCKFILE
# TODO kill rump server, but we need to compile shutdown!

# show if passed

if [ $EC -ne 0 ]
then
	echo "FAIL: $EC tests failed"
	exit 1
else
	echo "PASSED"
	exit 0
fi