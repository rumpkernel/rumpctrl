#include "rumprun_common.c"

#include <rump/rump_syscalls.h>

int
main(int argc, char *argv[])
{
	int ret;
	rump_init();
	ret = rumprun_so(argc, argv);
	rump_sys_reboot(0, NULL);
	return ret;
}
