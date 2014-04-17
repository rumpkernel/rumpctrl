OBJDIR=	obj-rr

BINDIR=bin

NBCFLAGS=${CFLAGS} -O2 -g -Wall
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

NBUTILS+=		external/bsd/wpa/bin/wpa_passphrase
NBUTILS+=		external/bsd/wpa/bin/wpa_supplicant

CPPFLAGS.umount=	-DSMALL

NBUTILS_BASE= $(notdir ${NBUTILS})

all:		${NBUTILS_BASE} bin/halt rumpremote.sh tools

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

NBCC=./rump/bin/rump-cc

netbsd_init.o:	netbsd_init.c tools
		${NBCC} ${NBCFLAGS} -c $< -o $@

halt.o:		halt.c tools
		${NBCC} ${NBCFLAGS} -c $< -o $@

bin/halt:	halt.o emul.o readwrite.o remoteinit.o exit.o nullenv.o rump.map
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
bin/${2}: rumpsrc/${1}/${2}.ro emul.o readwrite.o remoteinit.o nullenv.o exit.o netbsd_init.o rump.map $${LIBS.${2}}
	./mkremote.sh ${2} rumpsrc/${1}/${2}.ro $${LIBS.${2}}

${2}:	bin/${2}

clean_${2}:
	( [ ! -d rumpsrc/${1} ] || ( cd rumpsrc/${1} && ${RUMPMAKE} cleandir && rm -f ${2}.ro ) )
endef
$(foreach util,${NBUTILS},$(eval $(call NBUTIL_templ,${util},$(notdir ${util}))))

# the compiler objects
.PHONY: tools
tools:			rump/bin/rump-cc rump/lib/rump-cc.specs

INSTALL_PATH=${PWD}

rump/bin/rump-cc:	cc.template
			cat $< | sed "s|@PATH@|${INSTALL_PATH}|g" > $@
			chmod +x $@

rump/lib/rump-cc.specs:	spec.template
			cat $< | sed "s|@PATH@|${PWD}|g" | sed "s|@LDLIBS@|${COMPLIBS}|g" > $@

clean: $(foreach util,${NBUTILS_BASE},clean_${util})
		rm -f *.o *~ rump.map ${PROGS} ${OBJDIR}/* ${BINDIR}/* rumpremote.sh
		rm -f test_disk-* test_busmem* disk1-* disk2-* csock-* csock1-* csock2-* raid.conf-*

cleanrump:	clean
		rm -rf obj rump rumpobj rumptools rumpdyn rumpdynobj

distcleanrump:	clean cleanrump
		rm -rf rumpsrc ./${OBJDIR}
