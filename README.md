[![Build Status](https://travis-ci.org/justincormack/rumprun.png)](https://travis-ci.org/justincormack/rumprun)

This is a small experimental wrapper for running programs that were written for a normal POSIX (NetBSD) system to run them under rump kernel.

For more information about the rump kernel see [https://www.netbsd.org/docs/rump/](https://www.netbsd.org/docs/rump/).

It takes a NetBSD program, example.com as set up now, and compiles it using the NetBSD ABI, and then dynamically opens it in a rump kernel environment.

To build: 
````
./buildnb.sh
make
export LD_LIBRARY_PATH=.:rumpdyn/lib
./rumprun example.so
````

Currently tested on Linux and FreeBSD, so should be generally portable. (FreeBSD needs a few tweaks to Makefile).

