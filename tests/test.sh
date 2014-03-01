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

# output

if [ $EC -ne 0 ]
then
	echo "FAIL: $EC tests failed"
	exit 1
else
	echo "PASSED"
	exit 0
fi
