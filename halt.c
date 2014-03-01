#include <unistd.h>
#include <sys/reboot.h>

int
main(int argc, char **argv)
{
	reboot(0, NULL);
	return 0;
}
