OBJDIR=	obj-rr

BINDIR=bin

NBCFLAGS=${CFLAGS} -O2 -g -Wall
HOSTCFLAGS=${CFLAGS} -O2 -g -Wall ${RUMPRUN_CPPFLAGS}

RUMPMAKE:=$(shell echo `pwd`/rumptools/rumpmake)

RUMPSRC?= rumpsrc

NBUTILS+=		bin/cat
NBUTILS+=		bin/chmod
NBUTILS+=		bin/cp
NBUTILS+=		bin/dd
NBUTILS+=		bin/df
NBUTILS+=		bin/ed
NBUTILS+=		bin/ln
NBUTILS+=		bin/ls
NBUTILS+=		bin/mkdir
NBUTILS+=		bin/mv
NBUTILS+=		bin/pax
NBUTILS+=		bin/rm
NBUTILS+=		bin/rmdir

NBUTILS+=		sbin/cgdconfig
NBUTILS+=		sbin/chown
NBUTILS+=		sbin/disklabel
NBUTILS+=		sbin/dump
NBUTILS+=		sbin/fsck
NBUTILS+=		sbin/fsck_ext2fs
NBUTILS+=		sbin/fsck_ffs
NBUTILS+=		sbin/fsck_msdos
NBUTILS+=		sbin/ifconfig
NBUTILS+=		sbin/mknod
NBUTILS+=		sbin/modstat
NBUTILS+=		sbin/mount
NBUTILS+=		sbin/mount_ext2fs
NBUTILS+=		sbin/mount_ffs
NBUTILS+=		sbin/mount_msdos
NBUTILS+=		sbin/mount_tmpfs
NBUTILS+=		sbin/newfs
NBUTILS+=		sbin/newfs_ext2fs
NBUTILS+=		sbin/newfs_msdos
NBUTILS+=		sbin/ping
NBUTILS+=		sbin/ping6
NBUTILS+=		sbin/raidctl
NBUTILS+=		sbin/reboot
NBUTILS+=		sbin/rndctl
NBUTILS+=		sbin/route
NBUTILS+=		sbin/sysctl
NBUTILS+=		sbin/umount

NBUTILS+=		usr.sbin/arp
NBUTILS+=		usr.sbin/dumpfs
NBUTILS+=		usr.sbin/ndp
NBUTILS+=		usr.sbin/npf/npfctl
NBUTILS+=		usr.sbin/vnconfig
NBUTILS+=		usr.sbin/pcictl
NBUTILS+=		usr.sbin/wlanctl

#NBUTILS+=		usr.bin/kdump
NBUTILS+=		usr.bin/ktrace

NBUTILS+=		external/bsd/wpa/bin/wpa_passphrase
NBUTILS+=		external/bsd/wpa/bin/wpa_supplicant

ifeq (${BUILDZFS},true)
NBUTILS+=		external/cddl/osnet/sbin/zfs
NBUTILS+=		external/cddl/osnet/sbin/zpool
NBUTILS+=		external/cddl/osnet/usr.bin/ztest
endif

CPPFLAGS.umount=	-DSMALL

NBUTILS_BASE= $(notdir ${NBUTILS})

NBCC=./rump/bin/rump-cc

ifeq (${BUILDFIBER},true)
LWP=_lwp_fiber.c
else
LWP=_lwp_pthread.c
HALT=bin/halt
endif

all:		${NBUTILS_BASE} ${HALT} bin-rr/pthread_test rumpremote.sh

rumpremote.sh: rumpremote.sh.in
		sed 's,XXXPATHXXX,$(PWD),' $< > $@

_lwp.o:		${LWP} ${NBCC}
		${NBCC} ${NBCFLAGS} -c $< -o $@

emul.o:		emul.c
		${CC} ${HOSTCFLAGS} -c $< -o $@

stub.o:		stub.c
		${CC} ${HOSTCFLAGS} -c $< -o $@

rumpclient.o:	rumpclient.c
		${CC} ${HOSTCFLAGS} -c $< -o $@

readwrite.o:	readwrite.c
		${CC} ${HOSTCFLAGS} -c $< -o $@

remoteinit.o:	remoteinit.c
		${CC} ${HOSTCFLAGS} -c $< -o $@

rumpinit.o:	rumpinit.c
		${CC} ${HOSTCFLAGS} -c $< -o $@

netbsd_init.o:	netbsd_init.c ${NBCC}
		${NBCC} ${NBCFLAGS} -c $< -o $@

halt.o:		halt.c ${NBCC}
		${NBCC} ${NBCFLAGS} -c $< -o $@

pthread_test.o:	pthread_test.c ${MAPS} ${NBCC}
		${NBCC} ${NBCFLAGS} -c $< -o $@

MAPS=rump.map namespace.map host.map netbsd.map readwrite.map emul.map weakasm.map

bin/halt:	halt.o _lwp.o emul.o rumpclient.o readwrite.o remoteinit.o ${MAPS}
		${NBCC} ${NBCFLAGS} -o bin/halt halt.o

bin-rr/pthread_test: pthread_test.o _lwp.o emul.o netbsd_init.o readwrite.o stub.o rumpinit.o ${MAPS}
		./mkrun.sh pthread_test pthread_test.o rump/lib/libpthread.a

rump.map:	${RUMPSRC}/sys/rump/rump.sysmap
		awk '{printf("%s\t%s\n",$$3,$$4)}' $< > $@

namespace.map:	${RUMPSRC}/lib/libc/include/namespace.h rump.map emul.map
		grep '#define' $< | grep -v NAMESPACE_H | awk '{printf("%s\t%s\n",$$2,$$3)}' > fns.map
		cat rump.map emul.map > all.map
		awk 'NR==FNR{a[$$1]=$$1;next}a[$$1]' all.map fns.map | awk '{printf("%s\t%s\n",$$2,$$1)}' > $@

weakasm.map:	${RUMPSRC}/lib/libc/sys/Makefile.inc ${RUMPMAKE}
		${RUMPMAKE} -f $< RUMPRUN=no -V '$${WEAKASM}' | xargs -n 1 echo | awk '{sub("\\..*", ""); printf("_sys_%s _%s\n", $$1, $$1);}' > $@

define NBUTIL_templ
rumpobj/${1}/${2}.ro:
	( cd ${RUMPSRC}/${1} && ${RUMPMAKE} obj && \
	    ${RUMPMAKE} LIBCRT0= BUILDRUMP_CFLAGS="-fPIC -std=gnu99 -D__NetBSD__ ${CPPFLAGS.${2}}" ${2}.ro )

NBLIBS.${2}:= $(shell cd ${RUMPSRC}/${1} && ${RUMPMAKE} -V '$${LDADD}' | sed 's/-L\S*//g')
LIBS.${2}=$${NBLIBS.${2}:-l%=rump/lib/lib%.a}
bin/${2}: rumpobj/${1}/${2}.ro _lwp.o emul.o rumpclient.o readwrite.o remoteinit.o netbsd_init.o ${MAPS} $${LIBS.${2}}
	${NBCC} ${NBCFLAGS} -o bin/${2} rumpobj/${1}/${2}.ro $${LIBS.${2}}

bin-rr/${2}: rumpobj/${1}/${2}.ro _lwp.o emul.o stub.o readwrite.o rumpinit.o netbsd_init.o ${MAPS} $${LIBS.${2}}
	./mkrun.sh ${2} rumpobj/${1}/${2}.ro $${LIBS.${2}}

ifeq (${BUILDFIBER},true)
${2}:	bin-rr/${2}
else
${2}:	bin/${2} bin-rr/${2}
endif

clean_${2}:
	( [ ! -d ${RUMPSRC}/${1} ] || ( cd ${RUMPSRC}/${1} && ${RUMPMAKE} cleandir && rm -f ${2}.ro ) )
endef
$(foreach util,${NBUTILS},$(eval $(call NBUTIL_templ,${util},$(notdir ${util}))))

INSTALL_PATH=${PWD}

${OBJDIR}:
		mkdir -p $@

${NBCC}:	cc.in rump/lib/rump-cc.specs rump/lib/ld
		cat $< | sed "s|@PATH@|${INSTALL_PATH}|g" > $@
		chmod +x $@

rump/lib/ld:	ld.in ${OBJDIR}
		cat $< | sed "s|@PATH@|${PWD}|g" > $@
		chmod +x $@

rump/lib/rump-cc.specs:	specs.in
		cat $< | sed "s|@PATH@|${PWD}|g" | sed "s|@LDLIBS@|${COMPLIBS}|g" > $@

clean: $(foreach util,${NBUTILS_BASE},clean_${util})
		rm -f *.o *~ rump.map namespace.map fns.map all.map weakasm.map ${PROGS} ${OBJDIR}/* ${BINDIR}/* rumpremote.sh
		rm -f test_disk-* test_busmem* disk1-* disk2-* csock-* csock1-* csock2-* raid.conf-*
		rm -f ${NBCC} rump/lib/rump-cc.specs

cleanrump:	clean
		rm -rf obj rump rumpobj rumptools rumpdyn rumpdynobj

distcleanrump:	clean cleanrump
		rm -rf ./${OBJDIR}
