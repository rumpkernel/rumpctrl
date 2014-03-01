#!/bin/sh

# Initial test script to sanity check

# set up environment
export LD_LIBRARY_PATH=.:rumpdyn/lib
EC=0

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

# output

if [ $EC -ne 0 ]
then
	echo "FAIL: $EC tests failed"
	exit 1
else
	echo "PASSED"
	exit 0
fi
