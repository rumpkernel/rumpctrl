#include <stdint.h>
#include <stddef.h>
#include <rump/rump_syscalls.h>

void rumprun_init (void) __attribute__((constructor (101)));
void rumprun_fini (void) __attribute__((destructor (1000)));

#include "netbsd_init.h"

void
rumprun_init()
{

	rump_init();
	_netbsd_init(isatty(STDOUT_FILENO));
}

void
rumprun_fini()
{
	rump_sys_reboot(0, NULL);
}

