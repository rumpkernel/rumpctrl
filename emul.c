/* convert to host format as necessary */

#include <stdint.h>
#include <errno.h>
#include <stddef.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <unistd.h>
#include <time.h>
#include <sys/time.h>
#include <sys/resource.h>

#include <rump/rumpclient.h>

/* difficult to include headers */
int rumpclient_fork(void);

/* TODO map errors better, and generally better error handling */
#define _NETBSD_EINVAL 22
#define _NETBSD_ENOSYS 78

/* host definition, might need fixing for other OS */
#ifdef __FreeBSD__
int *
__errno(void)
{
        return __error();
}
#elif __NetBSD__
/* nothing as __errno is in libc */
#else
int * __errno_location(void);
int *
__errno(void)
{
        return __errno_location();
}
#endif

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

struct _netbsd_rusage {
  struct _netbsd_timeval ru_utime;
  struct _netbsd_timeval ru_stime;
  long    ru_maxrss;
  long    ru_ixrss;
  long    ru_idrss;
  long    ru_isrss;
  long    ru_minflt;
  long    ru_majflt;
  long    ru_nswap;
  long    ru_inblock;
  long    ru_oublock;
  long    ru_msgsnd;
  long    ru_msgrcv;
  long    ru_nsignals;
  long    ru_nvcsw;
  long    ru_nivcsw;
};

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
		errno = _NETBSD_ENOSYS;
		return (void *) -1;
	}

        memp = mmap(NULL, length, PROT_READ | PROT_WRITE, MAP_SHARED | MAP_ANON, -1, 0);
	if (memp == MAP_FAILED) {
		errno = _NETBSD_EINVAL;
		return (void *) -1;
	}

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
	return rumpclient_fork();
}

int
__vfork14(void)
{
	return rumpclient_fork();
}

static int rusage_map[2] = {
  RUSAGE_SELF,
  RUSAGE_CHILDREN,
};

int
__getrusage50(int who, struct _netbsd_rusage *nrusage)
{
	struct rusage rusage;
	int ok;
	if (who < 0 || who >= 2) {
		errno = _NETBSD_EINVAL;
		return -1;
	}
	who = rusage_map[who];
	ok = getrusage(who, &rusage);
	memset(nrusage, 0, sizeof(struct _netbsd_rusage));
	nrusage->ru_utime.tv_sec = rusage.ru_utime.tv_sec;
	nrusage->ru_utime.tv_usec = rusage.ru_utime.tv_usec;
	nrusage->ru_stime.tv_sec = rusage.ru_stime.tv_sec;
	nrusage->ru_stime.tv_usec = rusage.ru_stime.tv_usec;
	/* TODO add rest of fields */
	return ok;
}

extern char **environ;

int
emul_execve(const char *filename, char *const argv[], char *const envp[])
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

#define STUB_ABORT(name) void name(void); void name(void) { abort(); }

STUB(__sigaction14);
STUB(__sigprocmask14);

STUB(_lwp_self);
STUB(__wait450);
STUB(kill);

STUB_ABORT(_lwp_kill);
