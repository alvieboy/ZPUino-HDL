#ifndef __BOARD_H__
#define __BOARD_H__

#define CLK_FREQ 80000000UL

#ifndef BOARD_MEMORYSIZE
#error Undefined board memory size
#endif

/* RBF file is 368011 bytes in size */
#define SPIOFFSET 0x60000

#define ALTERA_FLASH 1

#define BOARD_SPI_DIVIDER BIT(SPICP0)

#define IOBASE 0x08000000
#define IO_SLOT_OFFSET_BIT 23

#define FPGA_PIN_LED1        8
#define FPGA_PIN_LED2        9
#define FPGA_PIN_LED3        10
#define FPGA_PIN_LED4        11

#define FPGA_PIN_FLASHCS     12

#define SPI_FLASH_SEL_PIN FPGA_PIN_FLASHCS

#endif
