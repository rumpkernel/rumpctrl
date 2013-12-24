CFLAGS=-nostdinc -nostdlib -fno-builtin-execve -I rump/include -O2 -g -Wall -fPIC

all:		example.so

example.o:	example.c

stub.o:		stub.c

emul.o:		emul.c
		${CC} -O2 -g -Wall -fPIC -D_FILE_OFFSET_BITS=64 -c $< -o emul.o
		objcopy --redefine-syms=emul.map emul.o

rumpmap:	
		cat ./rumpsrc/sys/rump/librump/rumpkern/rump_syscalls.c | \
			grep rsys_aliases | grep -v -- '#define' | \
			sed -e 's/rsys_aliases(//g' -e 's/);//g' -e 's/\(.*\),\(.*\)/\1\t\t\2/g' \
			> rump.map

rump/lib/libc.a:	
		./buildnb.sh

example.so:	example.o emul.o stub.o rumpmap rump/lib/libc.a
		${CC} $< rump/lib/libc.a emul.o stub.o -nostdlib -shared -Wl,-soname,example.so -o example.so
		objcopy --redefine-syms=extra.map example.so
		objcopy --redefine-syms=rump.map example.so

clean:		
		rm -f *.o *.so *~ rump.map

cleanrump:	clean
		rm -rf obj rump rumpobj rumpsrc rumptools
