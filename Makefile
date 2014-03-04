OBJDIR=	obj-rr

UNAME := $(shell uname -s)
ifeq ($(UNAME),Linux)
	DLFLAG=-ldl -Wl,--no-as-needed -lrt
endif

DEFUNDEF=-D__NetBSD__ -U__FreeBSD__ -Ulinux -U__linux -U__linux__ -U__gnu_linux__
NBCFLAGS=-nostdinc -nostdlib -Irump/include -O2 -g -Wall -fPIC  ${DEFUNDEF}
HOSTCFLAGS=-O2 -g -Wall -Irumpdyn/include
RUMPLIBS=-Lrumpdyn/lib -Wl,--no-as-needed -lrumpvfs -lrumpfs_kernfs -lrumpdev -lrumpnet_local -lrumpnet_netinet -lrumpnet_netinet6 -lrumpnet_net -lrumpnet -lrump -lrumpuser
RUMPCLIENT=-Lrumpdyn/lib -Wl,-R$(PWD)/rumpdyn/lib -lrumpclient

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
NBUTILS+=		bin/rmdir

NBUTILS+=		sbin/cgdconfig
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
NBUTILS+=		sbin/raidctl
NBUTILS+=		sbin/reboot
NBUTILS+=		sbin/rndctl
NBUTILS+=		sbin/route
NBUTILS+=		sbin/sysctl
NBUTILS+=		sbin/umount

NBUTILS+=		usr.sbin/ndp
NBUTILS+=		usr.sbin/npf/npfctl
NBUTILS+=		usr.sbin/vnconfig
NBUTILS+=		usr.sbin/pcictl

#NBUTILS+=		usr.bin/kdump
NBUTILS+=		usr.bin/ktrace

CPPFLAGS.umount=	-DSMALL

NBUTILS_BASE= $(notdir ${NBUTILS})
NBUTILSSO=$(NBUTILS_BASE:%=%.so)

PROGS=rumprun rumpremote

all:		${NBUTILSSO} ${PROGS} halt.so

rumprun.o:	rumprun.c rumprun_common.c
		${CC} ${HOSTCFLAGS} -c $< -o $@

rumprun:	rumprun.o
		${CC} $< -o $@ ${RUMPLIBS} -lc ${DLFLAG}

rumpremote.o:	rumpremote.c rumprun_common.c
		${CC} ${HOSTCFLAGS} -c $< -o $@

rumpremote:	rumpremote.o
		${CC} $< -o $@ ${RUMPCLIENT} -lc ${DLFLAG}

emul.o:		emul.c
		${CC} ${HOSTCFLAGS} -fPIC -c $< -o $@

exit.o:		exit.c
		${CC} ${HOSTCFLAGS} -fPIC -c $< -o $@

readwrite.o:	readwrite.c
		${CC} ${HOSTCFLAGS} -fPIC -c $< -o $@

halt.o:		halt.c
		${CC} ${NBCFLAGS} -c $< -o $@

# this should be refactored into a script...
halt.so:	halt.o
	${CC} -Wl,-r -nostdlib $< rump/lib/libc.a -o ${OBJDIR}/tmp1_halt.o
	objcopy --redefine-syms=extra.map ${OBJDIR}/tmp1_halt.o
	objcopy --redefine-syms=rump.map ${OBJDIR}/tmp1_halt.o
	objcopy --redefine-syms=emul.map ${OBJDIR}/tmp1_halt.o
	objcopy --redefine-sym environ=_netbsd_environ ${OBJDIR}/tmp1_halt.o
	objcopy --redefine-sym exit=_netbsd_exit ${OBJDIR}/tmp1_halt.o
	${CC} -Wl,-r -nostdlib -Wl,-dc ${OBJDIR}/tmp1_halt.o exit.o readwrite.o -o ${OBJDIR}/tmp2_halt.o
	objcopy -w -L '*' ${OBJDIR}/tmp2_halt.o
	objcopy --globalize-symbol=emul_main_wrapper \
	    --globalize-symbol=_netbsd_environ \
	    --globalize-symbol=_netbsd_exit ${OBJDIR}/tmp2_halt.o
	${CC} ${OBJDIR}/tmp2_halt.o emul.o  -shared -Wl,-dc -Wl,-soname,$@ -nostdlib -o $@

rump.map:	
		cat ./rumpsrc/sys/rump/librump/rumpkern/rump_syscalls.c | \
			grep rsys_aliases | grep -v -- '#define' | \
			sed -e 's/rsys_aliases(//g' -e 's/);//g' -e 's/\(.*\),\(.*\)/\1@\2/g' | \
			awk -F @ '$$1 ~ /^(read|write)$$/{$$2="rumprun_" $$1 "_wrapper"}{printf "%s\t%s\n", $$1, $$2}' > $@

${OBJDIR}:
	mkdir -p ${OBJDIR}

define NBUTIL_templ
rumpsrc/${1}/${2}.ro:
	( cd rumpsrc/${1} && \
	    ${RUMPMAKE} LIBCRT0= BUILDRUMP_CFLAGS="-fPIC -std=gnu99 -D__NetBSD__ ${CPPFLAGS.${2}}" ${2}.ro )

NBLIBS.${2}:= $(shell cd rumpsrc/${1} && ${RUMPMAKE} -V '$${LDADD}')
LIBS.${2}=$${NBLIBS.${2}:-l%=rump/lib/lib%.a} rump/lib/libc.a
${2}.so: rumpsrc/${1}/${2}.ro emul.o exit.o readwrite.o rump.map $${LIBS.${2}} ${OBJDIR}
	${CC} -Wl,-r -nostdlib rumpsrc/${1}/${2}.ro $${LIBS.${2}} -o ${OBJDIR}/tmp1_${2}.o
	objcopy --redefine-syms=extra.map ${OBJDIR}/tmp1_${2}.o
	objcopy --redefine-syms=rump.map ${OBJDIR}/tmp1_${2}.o
	objcopy --redefine-syms=emul.map ${OBJDIR}/tmp1_${2}.o
	objcopy --redefine-sym environ=_netbsd_environ ${OBJDIR}/tmp1_${2}.o
	objcopy --redefine-sym exit=_netbsd_exit ${OBJDIR}/tmp1_${2}.o
	${CC} -Wl,-r -nostdlib -Wl,-dc ${OBJDIR}/tmp1_${2}.o exit.o readwrite.o -o ${OBJDIR}/tmp2_${2}.o
	objcopy -w -L '*' ${OBJDIR}/tmp2_${2}.o
	objcopy --globalize-symbol=emul_main_wrapper \
	    --globalize-symbol=_netbsd_environ \
	    --globalize-symbol=_netbsd_exit ${OBJDIR}/tmp2_${2}.o
	${CC} ${OBJDIR}/tmp2_${2}.o emul.o  -shared -Wl,-dc -Wl,-soname,${2}.so -nostdlib -o ${2}.so

clean_${2}:
	( [ ! -d rumpsrc/${1} ] || ( cd rumpsrc/${1} && ${RUMPMAKE} cleandir && rm -f ${2}.ro ) )
endef
$(foreach util,${NBUTILS},$(eval $(call NBUTIL_templ,${util},$(notdir ${util}))))

clean: $(foreach util,${NBUTILS_BASE},clean_${util})
		rm -f *.o *.so *~ rump.map ${PROGS} ${OBJDIR}/*

cleanrump:	clean
		rm -rf obj rump rumpobj rumptools rumpdyn rumpdynobj

distcleanrump:	clean cleanrump
		rm -rf rumpsrc ./${OBJDIR}
