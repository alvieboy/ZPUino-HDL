#ifndef __TRANSPORT_H__
#define __TRANSPORT_H__

#include <sys/types.h>

typedef struct {
	unsigned char *buf;
	size_t size;
} buffer_t;

void buffer_free(buffer_t *b);

#endif
