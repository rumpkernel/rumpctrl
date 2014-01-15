/* convert to host format as necessary */

#include <stdint.h>
#include <errno.h>

/* it would make sense to directly call host interfaces here
   but the symbols are not available so use rumpuser interfaces for now
*/

#include <rump/rumpclient.h>

#define LIBRUMPUSER
#include <rump/rump.h>
#include <rump/rumpuser.h>

#define _NETBSD_ENOSYS 78

/* host definition, might need fixing for other OS */
int * __errno_location(void);

int *
__errno(void)
{
        return __errno_location();
}

typedef int64_t _netbsd_time_t;
typedef int _netbsd_suseconds_t;
typedef int64_t _netbsd_off_t;
typedef int _netbsd_clockid_t;

struct _netbsd_timeval {
	_netbsd_time_t tv_sec;
	_netbsd_suseconds_t tv_usec;
};

struct _netbsd_timespec {
	_netbsd_time_t tv_sec;
	long   tv_nsec;
};

int
__gettimeofday50(struct _netbsd_timeval *ntv, void *ntz)
{
	int64_t sec;
        long nsec;
	int ok = rumpuser_clock_gettime(RUMPUSER_CLOCK_RELWALL, &sec, &nsec);
	ntv->tv_sec = sec;
	ntv->tv_usec = nsec / 1000;
	return ok;
}

static int clockmap[4] = {
  RUMPUSER_CLOCK_RELWALL,	/* CLOCK_REALTIME */
  -1,				/* CLOCK_VIRTUAL */
  -1,				/* CLOCK_PROF */
  RUMPUSER_CLOCK_ABSMONO,	/* CLOCK_MONOTONIC */
};

int
__clock_gettime50(_netbsd_clockid_t clock_id, struct _netbsd_timespec *res)
{
	int rump_clock_id = clockmap[clock_id];
        int64_t sec;
	long nsec;
	int rv;
	if (rump_clock_id == -1) {
		errno = _NETBSD_ENOSYS;
		return -1;
	}
	rv = rumpuser_clock_gettime(rump_clock_id, &sec, &nsec);
	res->tv_sec = sec;
	res->tv_nsec = nsec;
	return rv;
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

void *
mmap(void *addr, size_t length, int prot, int nflags, int fd, _netbsd_off_t offset)
{
	void *memp;
        int ret;

	if (! (fd == -1 && nflags & _NETBSD_MAP_ANON)) {
		rumpuser_seterrno(_NETBSD_ENOSYS);
		return (void *) -1;
	}

	ret = rumpuser_malloc(length, 4096, &memp);
	if (! ret) return (void *) -1;

	return memp;
}

/* not sure why we have both, may need to fix */
void *
_mmap(void *addr, size_t length, int prot, int nflags, int fd, _netbsd_off_t offset)
{
	return mmap(addr, length, prot, nflags, fd, offset);
}

int
munmap(void *addr, size_t len)
{
	rumpuser_free(addr, len);
	return 0; /* rumpuser_free is void */
}

int
madvise(void *addr, size_t length, int advice)
{
	/* thanks for the advice */
	return 0;
}

int
setpriority(int which, int who, int prio) {
	/* don't prioritise */
	return 0;
}

int
__fork(void)
{
	rumpclient_fork();
}

int
__vfork14(void)
{
	rumpclient_fork();
}

