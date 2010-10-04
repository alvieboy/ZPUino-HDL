#ifndef __TRANSPORT_H__
#define __TRANSPORT_H__

#include <sys/types.h>


typedef struct {
	unsigned char *buf;
	size_t size;
} buffer_t;

buffer_t *sendreceive(int fd, unsigned char *txbuf, size_t size, int timeout);
buffer_t *sendreceivecommand(int fd, unsigned char cmd, unsigned char *txbuf, size_t size, int timeout);

void buffer_free(buffer_t *b);

#endif
