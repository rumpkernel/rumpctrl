#!/bin/sh

# Initial test script to sanity check

export LD_LIBRARY_PATH=.:rumpdyn/lib

./rumprun ifconfig
./rumprun sysctl kern.hostname
./rumprun df

