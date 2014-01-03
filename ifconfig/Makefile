DEFUNDEF=-D__NetBSD__ -U__FreeBSD__ -Ulinux -U__linux -U__linux__ -U__gnu_linux__
CFLAGS=-nostdinc -nostdlib -I../rump/include -I. -Ilibutil -O2 -g -Wall -fPIC ${DEFUNDEF} -DINET6

SRCS=af_atalk.c af_inetany.c af_link.c carp.c ether.c ifconfig.c parse.c tunnel.c vlan.c af_inet6.c af_inet.c agr.c env.c ieee80211.c ifconfig_hostops.c media.c util.c

OBJS=$(SRCS:.c=.o)

USRCS=libutil/disklabel_dkcksum.c  libutil/getlabelsector.c    libutil/login_tty.c  libutil/passwd.c                libutil/stat_flags.c libutil/disklabel_scan.c     libutil/getmaxpartitions.c  libutil/loginx.c     libutil/pidfile.c               libutil/strpct.c libutil/efun.c               libutil/getmntopts.c        libutil/logout.c     libutil/pidlock.c               libutil/ttyaction.c libutil/getbootfile.c        libutil/getrawpartition.c   libutil/logoutx.c    libutil/pty.c                   libutil/ttymsg.c libutil/getbyteorder.c       libutil/if_media.c          libutil/logwtmp.c    libutil/raise_default_signal.c libutil/getdiskrawname.c     libutil/login.c             libutil/logwtmpx.c   libutil/secure_path.c libutil/getfsspecname.c      libutil/login_cap.c         libutil/opendisk.c   libutil/sockaddr_snprintf.c libutil/getfstypename.c  libutil/proc_compare.c  libutil/snprintb.c libutil/compat/compat_passwd.c
UOBJS = $(USRCS:.c=.o)

PSRCS=libprop/prop_array.c libprop/prop_data.c             libprop/prop_ingest.c  libprop/prop_object.c  libprop/prop_string.c libprop/prop_array_util.c  libprop/prop_dictionary.c       libprop/prop_kern.c    libprop/prop_rb.c      libprop/prop_bool.c        libprop/prop_dictionary_util.c  libprop/prop_number.c  libprop/prop_stack.c
POBJS = $(PSRCS:.c=.o)

all:	ifall.o

dummy.o:	dummy.c

libutil.o:	${UOBJS}
		${CC} -Wl,-r -nostdlib ${UOBJS} -o $@

libprop.o:	${POBJS}
		${CC} -Wl,-r -nostdlib ${POBJS} -o $@

ifall.o:	${OBJS} libutil.o libprop.o dummy.o
		${CC} -Wl,-r -nostdlib ${OBJS} libutil.o libprop.o dummy.o -o $@


clean:		
		rm -f *.o *.so *~ libutil/*.o libprop/*.o
