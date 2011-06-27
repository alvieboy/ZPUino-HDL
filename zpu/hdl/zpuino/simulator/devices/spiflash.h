#ifndef __SPIFLASH_H__
#define __SPIFLASH_H__

void spiflash_reset();
void spiflash_select();
void spiflash_deselect();
unsigned int spiflash_read();
void spiflash_write(unsigned int);
int spiflash_mapbin(const char *name);

#endif
