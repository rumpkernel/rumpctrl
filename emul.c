/* convert to host format as necessary */

#include <stdint.h>
#include <errno.h>
#include <stddef.h>

#include <sys/mman.h>
#include <unistd.h>
#include <time.h>

/* it would make sense to directly call host interfaces here
   but the symbols are not available so use rumpuser interfaces for now
*/

#include <rump/rumpclient.h>

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
	struct timeval tv;
	int ok = gettimeofday(&tv, NULL);
	ntv->tv_sec = tv.tv_sec;
	ntv->tv_usec = tv.tv_usec;
	return ok;
}

static int clockmap[4] = {
  CLOCK_REALTIME,
#ifdef CLOCK_VIRTUAL
  CLOCK_VIRTUAL,
#else
  -1,
#endif
#ifdef CLOCK_PROF
  CLOCK_PROF,
#else
  -1,
#endif
  CLOCK_MONOTONIC,
};

int
__clock_gettime50(_netbsd_clockid_t clock_id, struct _netbsd_timespec *res)
{
	int host_clock_id = clockmap[clock_id];
        struct timespec ts;
	int rv;
	if (host_clock_id == -1) {
		errno = _NETBSD_ENOSYS;
		return -1;
	}
	rv = clock_gettime(host_clock_id, &ts);
	res->tv_sec = ts.tv_sec;
	res->tv_nsec = ts.tv_nsec;
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
emul_mmap(void *addr, size_t length, int prot, int nflags, int fd, _netbsd_off_t offset)
{
	void *memp;

	if (! (fd == -1 && nflags & _NETBSD_MAP_ANON)) {
		rumpuser_seterrno(_NETBSD_ENOSYS);
		return (void *) -1;
	}

        memp = mmap(NULL, length, PROT_READ | PROT_WRITE, MAP_SHARED | MAP_ANON, -1, 0);
	if (memp == MAP_FAILED)
		return (void *) -1;

	return memp;
}

/* not sure why we have both, may need to fix */
void *
_mmap(void *addr, size_t length, int prot, int nflags, int fd, _netbsd_off_t offset)
{
	return emul_mmap(addr, length, prot, nflags, fd, offset);
}

int
emul_munmap(void *addr, size_t len)
{
	munmap(addr, len);
	return 0;
}

int
emul_madvise(void *addr, size_t length, int advice)
{
	/* thanks for the advice TODO can add */
	return 0;
}

int
emul_setpriority(int which, int who, int prio) {
	/* don't prioritise TODO can add */
	return 0;
}

int
__fork(void)
{
	return fork();
}

int
__vfork14(void)
{
	return fork();
}

extern char **environ;

int
execve(const char *filename, char *const argv[], char *const envp[])
{
	return rumpclient_exec(filename, argv, environ);
}


/*
 * BEGIN stubs
 */

#define STUB(name)                              \
  int name(void); int name(void) {              \
        static int done = 0;                    \
        errno = ENOTSUP;                        \
        if (done) return ENOTSUP; done = 1;     \
      /*printk("STUB ``%s'' called\n", #name);*/\
        return ENOTSUP;}

#define STUB_ABORT(name) void name(void); void name(void) { rumpuser_exit(-1); }

STUB(__nanosleep50);
STUB(__setitimer50);
STUB(__sigaction14);
STUB(__sigprocmask14);
STUB(__getrusage50);

STUB(_lwp_self);
STUB(__wait450);
STUB(kill);

STUB_ABORT(_lwp_kill);
