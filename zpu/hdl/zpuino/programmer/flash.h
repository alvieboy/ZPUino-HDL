#ifndef __FLASH_H__
#define __FLASH_H__

#include "transport.h"

typedef struct {
	int (*erase_sector)(int fd, unsigned sector);
	int (*enable_writes)(int fd);
	buffer_t *(*read_page)(int fd, unsigned page);
	int (*program_page)(int fd, unsigned page, const unsigned char *data, size_t size);
} flash_driver_t;

typedef struct {
	unsigned int manufacturer;
	unsigned int product;
	unsigned int density;
	unsigned int pagesize;
	unsigned int sectorsize;
	const char *name;
	flash_driver_t *driver;
} flash_info_t;


extern flash_info_t flash_list[];

flash_info_t *find_flash(unsigned int manufacturer,unsigned int product, unsigned int density);

#endif
