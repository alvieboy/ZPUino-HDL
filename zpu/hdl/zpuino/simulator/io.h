#ifndef __IO_H__
#define __IO_H__
#include <poll.h>

typedef int (*poll_callback_t)(short);
int poll_add(int fd, short events, poll_callback_t c);
int poll_remove(int fd);
int poll_init();
void poll_loop();

#endif
