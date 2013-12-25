DEFUNDEF=-D__NetBSD__ -U__FreeBSD__ -Ulinux -U__linux -U__linux__ -U__gnu_linux__
NBCFLAGS=-nostdinc -nostdlib -Irump/include -O2 -g -Wall -fPIC  ${DEFUNDEF}
HOSTCFLAGS=-O2 -g -Wall -Irumpdyn/include
RUMPLIBS=-Lrumpdyn/lib -Wl,--no-as-needed -lrumpvfs -lrumpfs_kernfs -lrump -lrumpuser

all:		example.so rumprun

stub.o:		stub.c
		${CC} ${NBCFLAGS} -fno-builtin-execve -c $< -o $@

rumprun.o:	rumprun.c
		${CC} ${HOSTCFLAGS} -c $< -o $@

rumprun:	rumprun.o
		${CC} $< -o $@ ${RUMPLIBS} -lc -ldl

emul.o:		emul.c
		${CC} -O2 -g -Wall -fPIC -D_FILE_OFFSET_BITS=64 -c $< -o $@

rump.map:	
		cat ./rumpsrc/sys/rump/librump/rumpkern/rump_syscalls.c | \
			grep rsys_aliases | grep -v -- '#define' | \
			sed -e 's/rsys_aliases(//g' -e 's/);//g' -e 's/\(.*\),\(.*\)/\1@\2/g' | \
			awk '{gsub("@","\t"); print;}' > $@

example.o:	example.c
		${CC} ${NBCFLAGS} -c $< -o $@

example.so:	example.o emul.o stub.o rump.map rump/lib/libc.a
		${CC} -Wl,-r -nostdlib example.o rump/lib/libc.a -o tmp1.o
		objcopy --redefine-syms=extra.map tmp1.o
		objcopy --redefine-syms=emul.map tmp1.o
		objcopy --redefine-syms=rump.map tmp1.o
		${CC} -Wl,-r -nostdlib tmp2.o emul.o stub.o -o tmp2.o
		objcopy -w -L '*' tmp2.o
		objcopy --globalize-symbol=main tmp2.o
		${CC} tmp2.o -nostdlib -shared -Wl,-soname,example.so -o example.so

clean:		
		rm -f *.o *.so *~ rump.map

cleanrump:	clean
		rm -rf obj rump rumpobj rumpsrc rumptools rumpdyn
