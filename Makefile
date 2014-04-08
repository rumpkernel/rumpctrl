OBJDIR=	obj-rr

BINDIR=bin

DEFUNDEF=-D__NetBSD__ -U__FreeBSD__ -Ulinux -U__linux -U__linux__ -U__gnu_linux__
NBCFLAGS=${CFLAGS} -nostdinc -nostdlib -Irump/include -O2 -g -Wall -fPIC  ${DEFUNDEF}
HOSTCFLAGS=${CFLAGS} -O2 -g -Wall -Irumpdyn/include
RUMPLIBS=-Lrumpdyn/lib -Wl,--no-as-needed -lrumpkern_time -lrumpvfs -lrumpfs_kernfs -lrumpdev -lrumpnet_local -lrumpnet_netinet -lrumpnet_netinet6 -lrumpnet_net -lrumpnet -lrump -lrumpuser rumpkern_time

RUMPMAKE:=$(shell echo `pwd`/rumptools/rumpmake)

NBUTILS+=		bin/cat
NBUTILS+=		bin/cp
NBUTILS+=		bin/dd
NBUTILS+=		bin/df
NBUTILS+=		bin/ln
NBUTILS+=		bin/ls
NBUTILS+=		bin/mkdir
NBUTILS+=		bin/mv
NBUTILS+=		bin/pax
NBUTILS+=		bin/rm
NBUTILS+=		bin/rmdir

NBUTILS+=		sbin/cgdconfig
NBUTILS+=		sbin/disklabel
NBUTILS+=		sbin/dump
NBUTILS+=		sbin/fsck
NBUTILS+=		sbin/fsck_ext2fs
NBUTILS+=		sbin/fsck_ffs
NBUTILS+=		sbin/fsck_lfs
NBUTILS+=		sbin/fsck_msdos
NBUTILS+=		sbin/fsck_v7fs
NBUTILS+=		sbin/ifconfig
NBUTILS+=		sbin/mknod
NBUTILS+=		sbin/modstat
NBUTILS+=		sbin/mount
NBUTILS+=		sbin/mount_ffs
NBUTILS+=		sbin/newfs
NBUTILS+=		sbin/newfs_ext2fs
NBUTILS+=		sbin/newfs_lfs
NBUTILS+=		sbin/newfs_msdos
NBUTILS+=		sbin/newfs_sysvbfs
NBUTILS+=		sbin/newfs_udf
NBUTILS+=		sbin/newfs_v7fs
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
NBUTILS+=		usr.sbin/makefs
NBUTILS+=		usr.sbin/ndp
NBUTILS+=		usr.sbin/npf/npfctl
NBUTILS+=		usr.sbin/vnconfig
NBUTILS+=		usr.sbin/pcictl
NBUTILS+=		usr.sbin/wlanctl

#NBUTILS+=		usr.bin/kdump
NBUTILS+=		usr.bin/ktrace

CPPFLAGS.umount=	-DSMALL

NBUTILS_BASE= $(notdir ${NBUTILS})

all:		${NBUTILS_BASE} halt rumpremote.sh

rumpremote.sh: rumpremote.sh.in
		sed 's,XXXPATHXXX,$(PWD),' $< > $@

emul.o:		emul.c
		${CC} ${HOSTCFLAGS} -c $< -o $@

exit.o:		exit.c
		${CC} ${HOSTCFLAGS} -c $< -o $@

readwrite.o:	readwrite.c
		${CC} ${HOSTCFLAGS} -c $< -o $@

rumpinit.o:	rumpinit.c
		${CC} ${HOSTCFLAGS} -c $< -o $@

remoteinit.o:	remoteinit.c
		${CC} ${HOSTCFLAGS} -c $< -o $@

nullenv.o:	nullenv.c
		${CC} ${HOSTCFLAGS} -c $< -o $@

halt.o:		halt.c
		${CC} ${NBCFLAGS} -c $< -o $@

halt:		halt.o emul.o readwrite.o remoteinit.o exit.o nullenv.o rump.map
		./mkremote.sh halt halt.o

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
LIBS.${2}=$${NBLIBS.${2}:-l%=rump/lib/lib%.a}
${2}:	rumpsrc/${1}/${2}.ro emul.o readwrite.o remoteinit.o nullenv.o exit.o rump.map $${LIBS.${2}} $(filter-out $(wildcard ${OBJDIR}), ${OBJDIR})
	./mkremote.sh ${2} rumpsrc/${1}/${2}.ro $${LIBS.${2}}

clean_${2}:
	( [ ! -d rumpsrc/${1} ] || ( cd rumpsrc/${1} && ${RUMPMAKE} cleandir && rm -f ${2}.ro ) )
endef
$(foreach util,${NBUTILS},$(eval $(call NBUTIL_templ,${util},$(notdir ${util}))))

clean: $(foreach util,${NBUTILS_BASE},clean_${util})
		rm -f *.o *~ rump.map ${PROGS} ${OBJDIR}/* ${BINDIR}/* rumpremote.sh
		rm -f test_disk-* test_busmem* disk1-* disk2-* csock-* csock1-* csock2-* raid.conf-*

cleanrump:	clean
		rm -rf obj rump rumpobj rumptools rumpdyn rumpdynobj

distcleanrump:	clean cleanrump
		rm -rf rumpsrc ./${OBJDIR}
