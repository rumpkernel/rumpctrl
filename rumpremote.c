/*
 * Like rumprun, except connects to a remote service.
 * Note, std* will be directed to the remote service (and they are
 * not even open by default), so example.so needs to be judiciously
 * selected, at least for now.
 */

#include "rumprun_common.c"

#include <rump/rumpclient.h>

int
main(int argc, char *argv[])
{
	int ret;

	ret = rumpclient_init();
	if (ret != 0)
		die("rumpclient init failed");
	return rumprun_so(argc, argv);
}
