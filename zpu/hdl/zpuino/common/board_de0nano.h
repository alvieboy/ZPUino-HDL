#ifndef __BOARD_H__
#define __BOARD_H__

#define CLK_FREQ 96000000UL

#ifndef BOARD_MEMORYSIZE
#error Undefined board memory size
#endif

/* RBF file is 368011 bytes in size */
#define SPIOFFSET 0x60000

#define ALTERA_FLASH 1

#define BOARD_SPI_DIVIDER BIT(SPICP0)

#define IOBASE 0x08000000
#define IO_SLOT_OFFSET_BIT 23

#define FPGA_PIN_FLASHCS     79
#define FPGA_PIN_LED0        80
#define FPGA_PIN_LED1        81
#define FPGA_PIN_LED2        82
#define FPGA_PIN_LED3        83
#define FPGA_PIN_LED4        84
#define FPGA_PIN_LED5        85
#define FPGA_PIN_LED6        86
#define FPGA_PIN_LED7        87

#define FPGA_PIN_KEY0        88
#define FPGA_PIN_KEY1        89

#define FPGA_PIN_DIP0        90
#define FPGA_PIN_DIP1        91
#define FPGA_PIN_DIP2        92
#define FPGA_PIN_DIP3        93

#define FPGA_PIN_ACCEL_CS    94
#define FPGA_PIN_ADC_CS      95



#define SPI_FLASH_SEL_PIN FPGA_PIN_FLASHCS

#endif
