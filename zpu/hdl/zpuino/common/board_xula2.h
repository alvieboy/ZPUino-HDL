#ifndef __BOARD_H__
#define __BOARD_H__

#define CLK_FREQ 96000000UL

/* LX9 bitfile is 0x5327C in size */
/* LX25 bitfile is 0xC48BE in size */

#define SPIOFFSET 0xD0000

#ifndef BOARD_MEMORYSIZE
#error Undefined board memory size
#endif

#define BOARD_SPI_DIVIDER BIT(SPICP0)

#define IOBASE 0x08000000
#define IO_SLOT_OFFSET_BIT 23

#define FPGA_PIN_FLASHCS     32
#define FPGA_PIN_SDCS        33

#define SPI_FLASH_SEL_PIN FPGA_PIN_FLASHCS

#endif
