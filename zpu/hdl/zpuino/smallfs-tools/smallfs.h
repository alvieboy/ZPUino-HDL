#ifndef __SMALLFS_H__
#define __SMALLFS_H__

#define SMALLFS_MAGIC 0x50411F50

struct smallfs_header {
	unsigned int magic;
	unsigned int numfiles;
}__attribute__((packed));

struct smallfs_entry {
	unsigned int foffset;
	unsigned int size;
	unsigned char fnamesize;
	char name[0];
} __attribute__((packed));

#endif
