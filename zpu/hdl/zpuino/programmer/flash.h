#ifndef __FLASH_H__
#define __FLASH_H__

#include "transport.h"
#include "programmer.h"

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
	int (*erase_sector)(flash_info_t *flash, connection_t conn, unsigned sector);
	int (*enable_writes)(flash_info_t *flash, connection_t conn);
	buffer_t *(*read_page)(flash_info_t *flash, connection_t conn, unsigned page);
	int (*program_page)(flash_info_t *flash, connection_t fd, unsigned page, const unsigned char *data, size_t size);
} flash_driver_t;



extern flash_info_t flash_list[];

flash_info_t *find_flash(unsigned int manufacturer,unsigned int product, unsigned int density);

#endif
