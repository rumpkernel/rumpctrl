#!/bin/sh

set -e

. ./config.mk

NAME=$1

shift

LINK=$*

BINDIR="bin-rr"
OBJDIR="obj-rr"

mkdir -p ${BINDIR} ${OBJDIR}

UNAME=$(uname -s)

# -lrt not always needed
[ ${UNAME} = Linux ] && DLFLAG="-ldl -lrt"

RUMPLIBS="-L${LIBRARY_PATH} -Wl,-R${LIBRARY_PATH} -Wl,--no-as-needed -lrumpvfs -lrumpfs_kernfs -lrumpfs_ffs ${ZFSLIBS} -lrumpdev_disk -lrumpdev -lrumpdev_rnd -lrumpnet -lrumpnet_net -lrumpnet_netinet -lrumpnet_netinet6 -lrumpuser -lrump"

CC=${CC-cc}

${CC} ${LDFLAGS} -Wl,-r -nostdlib $LINK -o ${OBJDIR}/${NAME}.o
objcopy --redefine-syms=host.map ${OBJDIR}/${NAME}.o ${OBJDIR}/tmp0_${NAME}.o
${CC} ${LDFLAGS} -Wl,-r ${OBJDIR}/tmp0_${NAME}.o netbsd_init.o -nostdlib rump/lib/libc.a -o ${OBJDIR}/tmp1_${NAME}.o 2>/dev/null
objcopy --redefine-syms=namespace.map ${OBJDIR}/tmp1_${NAME}.o
objcopy --redefine-syms=extra.map ${OBJDIR}/tmp1_${NAME}.o
objcopy --redefine-syms=rump.map ${OBJDIR}/tmp1_${NAME}.o
objcopy --redefine-syms=weakasm.map ${OBJDIR}/tmp1_${NAME}.o
objcopy --redefine-syms=readwrite.map ${OBJDIR}/tmp1_${NAME}.o
objcopy --redefine-syms=emul.map ${OBJDIR}/tmp1_${NAME}.o
objcopy --redefine-syms=netbsd.map ${OBJDIR}/tmp1_${NAME}.o
${CC} ${LDFLAGS} -Wl,-r -nostdlib -Wl,-dc ${OBJDIR}/tmp1_${NAME}.o _lwp.o readwrite.o -o ${OBJDIR}/tmp2_${NAME}.o  2>/dev/null
objcopy --redefine-syms=errno.map ${OBJDIR}/tmp2_${NAME}.o
objcopy -w --localize-symbol='*' ${OBJDIR}/tmp2_${NAME}.o
objcopy -w --globalize-symbol='_netbsd_*' ${OBJDIR}/tmp2_${NAME}.o

${CC} ${CFLAGS} ${OBJDIR}/tmp2_${NAME}.o emul.o stub.o rumpinit.o ${RUMPLIBS} ${DLFLAG} -o ${BINDIR}/${NAME}

