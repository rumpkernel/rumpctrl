/*
 * This is a demonstration program to test pthreads on rumprun.
 * It's not very complete ...
 */

#include <sys/types.h>

#include <err.h>
#include <errno.h>
#include <pthread.h>
#include <unistd.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>

static pthread_mutex_t mtx;
static pthread_cond_t cv, cv2;

static int nthreads = 4;

static void
threxit(void *arg)
{

	pthread_mutex_lock(&mtx);
	if (--nthreads == 0) {
		printf("signalling\n");
		pthread_cond_signal(&cv2);
	}
	pthread_mutex_unlock(&mtx);

	printf("thread %p EXIT %d\n", arg, nthreads);
}

static void *
mythread(void *arg)
{

	printf("thread %p\n", arg);

	pthread_mutex_lock(&mtx);
	printf("got lock %p\n", arg);
	sched_yield();
	pthread_mutex_unlock(&mtx);
	printf("unlocked lock %p\n", arg);
	sched_yield();

	threxit(arg);

	return NULL;
}

static int predicate;

static void *
waitthread(void *arg)
{

	printf("thread %p\n", arg);
	pthread_mutex_lock(&mtx);
	while (!predicate) {
		printf("no good, need to wait\n");
		pthread_cond_wait(&cv, &mtx);
	}
	pthread_mutex_unlock(&mtx);
	printf("condvar complete!\n");

	threxit(arg);

	return NULL;
}

static void *
wakeupthread(void *arg)
{

	printf("thread %p\n", arg);
	pthread_mutex_lock(&mtx);
	predicate = 1;
	printf("rise and shine!\n");
	pthread_cond_signal(&cv);
	pthread_mutex_unlock(&mtx);

	threxit(arg);

	return NULL;
}

int
main(int argc, char **argv)
{
	pthread_t pt;
	int rounds = 0;

	if (pthread_create(&pt, NULL, mythread, (void *)0x01) != 0)
		errx(1, "pthread_create()");
	if (pthread_create(&pt, NULL, mythread, (void *)0x02) != 0)
		errx(1, "pthread_create()");
	if (pthread_create(&pt, NULL, waitthread, (void *)0x03) != 0)
		errx(1, "pthread_create()");
	if (pthread_create(&pt, NULL, wakeupthread, (void *)0x04) != 0)
		errx(1, "pthread_create()");
	pthread_mutex_init(&mtx, NULL);
	pthread_cond_init(&cv, NULL);
	pthread_cond_init(&cv2, NULL);

	pthread_mutex_lock(&mtx);
	while (nthreads) {
		printf("mainthread condwaiting\n");
		pthread_cond_wait(&cv2, &mtx);
		if (rounds++ > 100) {
			printf("condwait broken?\n");
			exit(1);
		}
	}
	pthread_mutex_unlock(&mtx);

	printf("main thread exit\n");
	return 0;
}
