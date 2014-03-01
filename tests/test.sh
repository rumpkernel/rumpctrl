#!/bin/sh

# Initial test script to sanity check

# set up environment
export LD_LIBRARY_PATH=.:rumpdyn/lib
EC=0

Basic_ifconfig()
{
echo "Basic ifconfig"
./rumprun ifconfig | grep lo0 > /dev/null
if [ $? -ne 0 ]
then 
	echo "ERROR Basic ifconfig"
	EC=`expr $EC + 1`
fi 
}
Basic_ifconfig

Basic_sysctl()
{
echo "Basic sysctl"
./rumprun sysctl kern.hostname | grep 'kern.hostname = rump-' > /dev/null
if [ $? -ne 0 ]
then 
	echo "ERROR Basic sysctl"
	EC=`expr $EC + 1`
fi 
}
Basic_sysctl

Basic_df()
{
echo "Basic df"
./rumprun df | grep rumpfs > /dev/null
if [ $? -ne 0 ]
then
	echo "ERROR Basic df"
	EC=`expr $EC + 1`
fi
}
Basic_df

Basic_cat()
{
echo "Basic cat"
./rumprun cat /dev/null > /dev/null
if [ $? -ne 0 ]
then
	echo "ERROR Basic cat"
	EC=`expr $EC + 1`
fi
}
Basic_cat

Basic_ping()
{
echo "Basic ping"
./rumprun ping -o 127.0.0.1 | grep '64 bytes from 127.0.0.1: icmp_seq=0' > /dev/null
if [ $? -ne 0 ]
then
	echo "ERROR Basic ping"
	EC=`expr $EC + 1`
fi
}
Basic_ping

Basic_ping6()
{
echo "Basic ping6"
./rumprun ping6 -c 1 ::1 | grep '16 bytes from ::1, icmp_seq=0' > /dev/null
if [ $? -ne 0 ]
then
	echo "ERROR Basic ping6"
	EC=`expr $EC + 1`
fi
}
Basic_ping6

# output

if [ $EC -ne 0 ]
then
	echo "FAIL: $EC tests failed"
	exit 1
else
	echo "PASSED"
	exit 0
fi
