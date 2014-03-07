#include <stdint.h>
#include <stddef.h>
#include <rump/rump_syscalls.h>

void rumprun_init (void) __attribute__((constructor (101)));
void rumprun_fini (void) __attribute__((destructor (1000)));

void
rumprun_init()
{
	rump_init();
}

void
rumprun_fini()
{
	rump_sys_reboot(0, NULL);
}

