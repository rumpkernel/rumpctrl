DEFUNDEF=-D__NetBSD__ -U__FreeBSD__ -Ulinux -U__linux -U__linux__ -U__gnu_linux__
NBCFLAGS=-nostdinc -nostdlib -Irump/include -O2 -g -Wall -fPIC  ${DEFUNDEF}
HOSTCFLAGS=-O2 -g -Wall -Irumpdyn/include
RUMPLIBS=-Lrumpdyn/lib -Wl,--no-as-needed -lrumpvfs -lrumpfs_kernfs -lrump -lrumpuser

all:		example.so rumprun

example.o:	example.c
		${CC} ${NBCFLAGS} -c $< -o $@

stub.o:		stub.c
		${CC} ${NBCFLAGS} -fno-builtin-execve -c $< -o $@

rumprun.o:	rumprun.c
		${CC} ${HOSTCFLAGS} -c $< -o $@

rumprun:	rumprun.o
		${CC} $< -o $@ ${RUMPLIBS} -lc -ldl

emul.o:		emul.c
		${CC} -O2 -g -Wall -fPIC -D_FILE_OFFSET_BITS=64 -c $< -o $@
		objcopy --redefine-syms=emul.map emul.o

rump.map:	
		cat ./rumpsrc/sys/rump/librump/rumpkern/rump_syscalls.c | \
			grep rsys_aliases | grep -v -- '#define' | \
			sed -e 's/rsys_aliases(//g' -e 's/);//g' -e 's/\(.*\),\(.*\)/\1@\2/g' | \
			awk '{gsub("@","\t"); print;}' > $@

munged.o:	example.o emul.o stub.o rump.map rump/lib/libc.a
		${CC} -Wl,-r -nostdlib $< emul.o stub.o rump/lib/libc.a -o $@
		objcopy --redefine-syms=extra.map $@
		objcopy --redefine-syms=rump.map $@
		# note that undefined symbols won't be localised
		objcopy -w -L '*' $@
		objcopy --globalize-symbol=main $@

example.so:	munged.o
		${CC} $< -nostdlib -shared -Wl,-soname,example.so -o $@

clean:		
		rm -f *.o *.so *~ rump.map

cleanrump:	clean
		rm -rf obj rump rumpobj rumpsrc rumptools rumpdyn
