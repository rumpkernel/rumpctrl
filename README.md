This is a small experimental wrapper for running programs that were written for a normal POSIX (NetBSD) system to run them under rump kernel.

It takes a NetBSD program, example.com as set up now, and compiles it using the NetBSD ABI, and then dynamically opens it in a rump kernel environment.

To build type ```make``` then ```export LD\_LIBRARY\_PATH=.:rumpdyn/lib``` ```./rumprun example.so```

Currently only works on Linux, as it uses ```RTLD_DEEPBIND``` but this will be fixed.

