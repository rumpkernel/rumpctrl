#include <unistd.h>
#include <sys/reboot.h>
#include <stdlib.h>

int
main(int argc, char **argv)
{

	(void)getprogname(); /* hack to get reference to __progname */
	reboot(0, NULL);
	exit(0); /* hack to get reference */
}
