#ifndef __FLASH_H__
#define __FLASH_H__

#include "transport.h"

struct flash_driver_t;

typedef struct {
	unsigned int manufacturer;
	unsigned int product;
	unsigned int density;
	unsigned int pagesize;
	unsigned int sectorsize;
	const char *name;
	struct flash_driver_t *driver;
} flash_info_t;

typedef struct flash_driver_t {
	int (*erase_sector)(flash_info_t *flash, int fd, unsigned sector);
	int (*enable_writes)(flash_info_t *flash, int fd);
	buffer_t *(*read_page)(flash_info_t *flash, int fd, unsigned page);
	int (*program_page)(flash_info_t *flash, int fd, unsigned page, const unsigned char *data, size_t size);
} flash_driver_t;



extern flash_info_t flash_list[];

flash_info_t *find_flash(unsigned int manufacturer,unsigned int product, unsigned int density);

#endif
