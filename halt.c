#include <unistd.h>
#include <sys/reboot.h>
#include <stdlib.h>

int
main(int argc, char **argv)
{
	(void)getenv("DUMMY"); /* hack to get reference */
	(void)getprogname(); /* hack to get reference */
	reboot(0, NULL);
	exit(0); /* hack to get reference */
}
