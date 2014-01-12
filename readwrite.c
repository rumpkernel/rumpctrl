#include <sys/types.h>
#include <fcntl.h>
#include <unistd.h>

/*
 * _Very_ cheap trick (for purposes of rumpremote): assume fd<=2 is
 * for stdio/stdout/stderr, so send it the console.  All other file
 * descriptors go to the rump kernel.  This of course should be
 * better tracked using something like rumphijack, but the cheap trick
 * allows to use most utils via rumpremote now.
 */

int rump___sysimpl_read(int, void *, size_t);
int rump___sysimpl_write(int, const void *, size_t);

int
rumprun_read_wrapper(int fd, void *buf, size_t blen)
{

	if (fd <= 2)
		return read(fd, buf, blen);
	else
		return rump___sysimpl_read(fd, buf, blen);
}

int
rumprun_write_wrapper(int fd, const void *buf, size_t blen)
{

	if (fd <= 2)
		return write(fd, buf, blen);
	else
		return rump___sysimpl_write(fd, buf, blen);
}
