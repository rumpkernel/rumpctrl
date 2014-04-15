/* init routines for NetBSD namespace */

#include <sys/types.h>

#include <stdio.h>
#include <string.h>

#include "netbsd_init.h"

void
_netbsd_init(int stdouttty)
{

	if (stdouttty)
		setlinebuf(stdout);
}
