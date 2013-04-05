#ifndef __SMALLFS_H__
#define __SMALLFS_H__

#define SMALLFS_MAGIC 0x50411F50
#include <inttypes.h>

struct smallfs_header {
	uint32_t magic;
	uint32_t numfiles;
}__attribute__((packed));

struct smallfs_entry {
	uint32_t foffset;
	uint32_t size;
	unsigned char fnamesize;
	char name[0];
} __attribute__((packed));

#endif
