DEFUNDEF=-D__NetBSD__ -U__FreeBSD__ -Ulinux -U__linux -U__linux__ -U__gnu_linux__
NBCFLAGS=-nostdinc -nostdlib -Irump/include -O2 -g -Wall -fPIC  ${DEFUNDEF}
HOSTCFLAGS=-O2 -g -Wall -Irumpdyn/include
RUMPLIBS=-Lrumpdyn/lib -Wl,--no-as-needed -lrumpvfs -lrumpfs_kernfs -lrumpdev -lrumpnet_local -lrumpnet_netinet -lrumpnet_netinet6 -lrumpnet_net -lrumpnet -lrump -lrumpuser
RUMPCLIENT=-Lrumpdyn/lib -lrumpclient -Wl,--no-as-needed -lrumpuser

RUMPMAKE:=$(shell echo `pwd`/rumptools/rumpmake)

NBUTILS+=		bin/cat
NBUTILS+=		bin/cp
NBUTILS+=		bin/dd
NBUTILS+=		bin/df
NBUTILS+=		bin/ln
NBUTILS+=		bin/ls
NBUTILS+=		bin/mkdir
NBUTILS+=		bin/mv
NBUTILS+=		bin/rm

NBUTILS+=		sbin/disklabel
NBUTILS+=		sbin/dump
NBUTILS+=		sbin/fsck
NBUTILS+=		sbin/fsck_ffs
NBUTILS+=		sbin/ifconfig
NBUTILS+=		sbin/mknod
NBUTILS+=		sbin/modstat
NBUTILS+=		sbin/mount
NBUTILS+=		sbin/mount_ffs
NBUTILS+=		sbin/newfs
NBUTILS+=		sbin/ping
NBUTILS+=		sbin/ping6
NBUTILS+=		sbin/rndctl
NBUTILS+=		sbin/route
NBUTILS+=		sbin/sysctl
NBUTILS+=		sbin/umount

NBUTILS+=		usr.sbin/ndp
NBUTILS+=		usr.sbin/vnconfig
NBUTILS+=		usr.sbin/pcictl

#NBUTILS+=		usr.bin/kdump
NBUTILS+=		usr.bin/ktrace

CPPFLAGS.umount=	-DSMALL

NBUTILS_BASE= $(notdir ${NBUTILS})
NBUTILSSO=$(NBUTILS_BASE:%=%.so)

PROGS=rumprun rumpremote

all:		${NBUTILSSO} ${PROGS}

stub.o:		stub.c
		${CC} ${NBCFLAGS} -fno-builtin-execve -c $< -o $@

rumprun.o:	rumprun.c rumprun_common.c
		${CC} ${HOSTCFLAGS} -c $< -o $@

rumprun:	rumprun.o
		${CC} $< -o $@ ${RUMPLIBS} -lc -ldl

rumpremote.o:	rumpremote.c rumprun_common.c
		${CC} ${HOSTCFLAGS} -c $< -o $@

rumpremote:	rumpremote.o
		${CC} $< -o $@ ${RUMPCLIENT} -lc -ldl

emul.o:		emul.c
		${CC} ${NBCFLAGS} -c $< -o $@

exit.o:		exit.c
		${CC} ${HOSTCFLAGS} -fPIC -c $< -o $@

readwrite.o:	readwrite.c
		${CC} ${HOSTCFLAGS} -fPIC -c $< -o $@

rump.map:	
		cat ./rumpsrc/sys/rump/librump/rumpkern/rump_syscalls.c | \
			grep rsys_aliases | grep -v -- '#define' | \
			sed -e 's/rsys_aliases(//g' -e 's/);//g' -e 's/\(.*\),\(.*\)/\1@\2/g' | \
			awk -F @ '$$1 ~ /^(read|write)$$/{$$2="rumprun_" $$1 "_wrapper"}{printf "%s\t%s\n", $$1, $$2}' > $@

define NBUTIL_templ
rumpsrc/${1}/${2}.ro:
	( cd rumpsrc/${1} && \
	    ${RUMPMAKE} LIBCRT0= BUILDRUMP_CFLAGS="-fPIC -std=gnu99 -D__NetBSD__ ${CPPFLAGS.${2}}" ${2}.ro )

NBLIBS.${2}:= $(shell cd rumpsrc/${1} && ${RUMPMAKE} -V '$${LDADD}')
LIBS.${2}=$${NBLIBS.${2}:-l%=rump/lib/lib%.a} rump/lib/libc.a
${2}.so: rumpsrc/${1}/${2}.ro emul.o exit.o readwrite.o stub.o rump.map $${LIBS.${2}}
	${CC} -Wl,-r -nostdlib rumpsrc/${1}/${2}.ro $${LIBS.${2}} -o tmp1_${2}.o
	objcopy --redefine-syms=extra.map tmp1_${2}.o
	objcopy --redefine-syms=rump.map tmp1_${2}.o
	objcopy --redefine-sym environ=_netbsd_environ tmp1_${2}.o
	objcopy --redefine-sym exit=_netbsd_exit tmp1_${2}.o
	${CC} -Wl,-r -nostdlib -Wl,-dc tmp1_${2}.o emul.o exit.o readwrite.o stub.o -o tmp2_${2}.o
	objcopy -w -L '*' tmp2_${2}.o
	objcopy --globalize-symbol=emul_main_wrapper \
	    --globalize-symbol=_netbsd_environ \
	    --globalize-symbol=_netbsd_exit tmp2_${2}.o
	${CC} tmp2_${2}.o -nostdlib -shared -Wl,-dc -Wl,-soname,${2}.so -o ${2}.so

clean_${2}:
	( [ ! -d rumpsrc/${1} ] || ( cd rumpsrc/${1} && ${RUMPMAKE} cleandir && rm -f ${2}.ro ) )
endef
$(foreach util,${NBUTILS},$(eval $(call NBUTIL_templ,${util},$(notdir ${util}))))

clean: $(foreach util,${NBUTILS_BASE},clean_${util})
		rm -f *.o *.so *~ rump.map ${PROGS}

cleanrump:	clean
		rm -rf obj rump rumpobj rumpsrc rumptools rumpdyn rumpdynobj
