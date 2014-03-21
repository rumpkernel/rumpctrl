#!/bin/sh

NAME=$1

shift

LINK=$*

BINDIR="bin"
OBJDIR="obj-rr"

mkdir -p ${BINDIR} ${OBJDIR}

UNAME=`uname -s`

[ ${UNAME} = Linux ] && DLFLAG="-ldl -Wl,--no-as-needed -lrt"

RUMPCLIENT="-Lrumpdyn/lib -Wl,-R${PWD}/rumpdyn/lib -lrumpclient"

CC=${CC-cc}

${CC} -Wl,-r -nostdlib $LINK -o ${OBJDIR}/tmp0_${NAME}.o
objcopy --redefine-syms=env.map ${OBJDIR}/tmp0_${NAME}.o
${CC} -Wl,-r ${OBJDIR}/tmp0_${NAME}.o -nostdlib rump/lib/libc.a -o ${OBJDIR}/tmp1_${NAME}.o 2>/dev/null
objcopy --redefine-syms=extra.map ${OBJDIR}/tmp1_${NAME}.o
objcopy --redefine-syms=rump.map ${OBJDIR}/tmp1_${NAME}.o
objcopy --redefine-syms=emul.map ${OBJDIR}/tmp1_${NAME}.o
objcopy --redefine-sym environ=_netbsd_environ ${OBJDIR}/tmp1_${NAME}.o
objcopy --redefine-sym main=_netbsd_main ${OBJDIR}/tmp1_${NAME}.o
objcopy --redefine-sym __progname=_netbsd__progname ${OBJDIR}/tmp1_${NAME}.o
objcopy --redefine-sym exit=_netbsd_exit ${OBJDIR}/tmp1_${NAME}.o
${CC} -Wl,-r -nostdlib -Wl,-dc ${OBJDIR}/tmp1_${NAME}.o readwrite.o -o ${OBJDIR}/tmp2_${NAME}.o  2>/dev/null
objcopy -w --localize-symbol='*' ${OBJDIR}/tmp2_${NAME}.o
objcopy -w --globalize-symbol='_netbsd_*' ${OBJDIR}/tmp2_${NAME}.o
${CC} ${OBJDIR}/tmp2_${NAME}.o emul.o exit.o remoteinit.o nullenv.o ${RUMPCLIENT} ${DLFLAG} -o ${BINDIR}/${NAME}

