/* convert to host format as necessary */

#include <stdint.h>
#include <stddef.h>
#include <sys/time.h>
#include <sys/mman.h>

typedef int64_t _netbsd_time_t;
typedef int _netbsd_suseconds_t;
typedef int64_t _netbsd_off_t;

struct _netbsd_timeval {
	_netbsd_time_t tv_sec;
	_netbsd_suseconds_t tv_usec;
};

int
emul_gettimeofday(struct _netbsd_timeval *ntv, void *ntz)
{
	struct timeval tv;
	int ok = gettimeofday(&tv, NULL);
	ntv->tv_sec = tv.tv_sec;
	ntv->tv_usec = tv.tv_usec;
	return ok;
}

#define _NETBSD_MAP_SHARED       0x0001
#define _NETBSD_MAP_PRIVATE      0x0002
#define _NETBSD_MAP_FILE         0x0000
#define _NETBSD_MAP_FIXED        0x0010
#define _NETBSD_MAP_RENAME       0x0020
#define _NETBSD_MAP_NORESERVE    0x0040
#define _NETBSD_MAP_INHERIT      0x0080
#define _NETBSD_MAP_HASSEMAPHORE 0x0200
#define _NETBSD_MAP_TRYFIXED     0x0400
#define _NETBSD_MAP_WIRED        0x0800
#define _NETBSD_MAP_ANON         0x1000
#define _NETBSD_MAP_STACK        0x2000

/* note that the PROT_ constants in NetBSD are the same as corresponding ones in Linux and FreeBSD at least, so no conversion */
int
emul_mmap(void *addr, size_t length, int prot, int nflags, int fd, _netbsd_off_t offset)
{
	int ok;
        int flags = 0;
        if (nflags & _NETBSD_MAP_SHARED) flags |= MAP_SHARED;
        if (nflags & _NETBSD_MAP_PRIVATE) flags |= MAP_PRIVATE;
        if (nflags & _NETBSD_MAP_ANON) flags |= MAP_ANON;
        if (nflags & _NETBSD_MAP_STACK) flags |= MAP_STACK;

	ok = mmap(addr, length, prot, flags, fd, offset);
	/* convert errors */
	return ok;
}

