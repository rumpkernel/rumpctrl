#include "rumprun_common.c"

#include <rump/rump_syscalls.h>

int
main(int argc, char *argv[])
{

	rump_init();
	rumprun_so(argc, argv);
	return rump_sys_reboot(0, NULL);
}
