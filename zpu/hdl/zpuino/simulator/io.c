#include "io.h"
#include <pthread.h>
#include <poll.h>
#include <string.h>
#include <stdio.h>

#if 0

static pthread_mutex_t pollfd_lock = PTHREAD_MUTEX_INITIALIZER;

struct mypolldata {
	struct pollfd pollfds[16];
	poll_callback_t pollcb[16];
	unsigned int numfds;
};

struct mypolldata pdata, cpdata;

int poll_add(int fd, short events, poll_callback_t c)
{
	pthread_mutex_lock(&pollfd_lock);
	pdata.pollfds[pdata.numfds].fd=fd;
	pdata.pollfds[pdata.numfds].events=events;
	pdata.pollcb[pdata.numfds]=c;
	pdata.numfds++;
	printf("Add POLL fd %d, total %d\n", fd, pdata.numfds);
	pthread_mutex_unlock(&pollfd_lock);
	return 0;
}

int poll_remove(int fd)
{
	int i;
	pthread_mutex_lock(&pollfd_lock);
	for (i=0; i<pdata.numfds; i++) {
		if (pdata.pollfds[i].fd==fd) {
			if (i<(pdata.numfds-1)) {
				memcpy( &pdata.pollfds[i], &pdata.pollfds[i+1], sizeof(struct pollfd)*(pdata.numfds-1-i));
				memcpy( &pdata.pollcb[i], &pdata.pollcb[i+1], sizeof(poll_callback_t)*(pdata.numfds-1-i));
			}
			pdata.numfds--;
			break;
		}
	}
	pthread_mutex_unlock(&pollfd_lock);
	return 0;
}

int poll_init()
{
	pthread_mutex_lock(&pollfd_lock);
	pdata.numfds=0;
	pthread_mutex_unlock(&pollfd_lock);
	return 0;
}

void poll_loop()
{
	int r,i;
	do {
		pthread_mutex_lock(&pollfd_lock);
		r = poll( &pdata.pollfds[0], pdata.numfds, -1);
		if (r>0) {
			memcpy(&cpdata,&pdata,sizeof(struct mypolldata));
		}
		pthread_mutex_unlock(&pollfd_lock);

		if (r>0) {
			for (i=0;i<cpdata.numfds;i++) {
				if (cpdata.pollfds[i].revents) {
					if ((*cpdata.pollcb[i])(cpdata.pollfds[i].revents)<0) {
						poll_remove(cpdata.pollfds[i].fd);
					}
				}
			}
		}
	} while (1);

}

#else

#include <glib.h>

static GMainLoop *mainloop;
 /*
struct {
	GIOChannel *channel;
	int fd;
}; */

void poll_stop()
{
	g_main_loop_quit(mainloop);
}

gboolean poll_changed(GIOChannel *source,GIOCondition condition,gpointer data)
{
	poll_callback_t c = (poll_callback_t)data;
	c(condition);
	return TRUE;
}

int poll_add(int fd, short events, poll_callback_t c)
{
	GError *err=NULL;
	GIOChannel *ch = g_io_channel_unix_new(fd);
	g_io_channel_set_encoding(ch, NULL, &err);
	g_io_channel_set_buffered(ch, FALSE);
	fprintf(stderr,"Add poll %d %d\n",fd, events);
	guint w = g_io_add_watch( ch, events, &poll_changed, c);
}

int poll_init()
{
	mainloop = g_main_loop_new(g_main_context_default(), TRUE);
}

void poll_loop()
{
	g_main_loop_run(mainloop);
}

#endif
