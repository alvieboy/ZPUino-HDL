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

#define WING_A_0 0
#define WING_A_1 1
#define WING_A_2 2
#define WING_A_3 3
#define WING_A_4 4
#define WING_A_5 5
#define WING_A_6 6
#define WING_A_7 7
#define WING_A_8 8
#define WING_A_9 9
#define WING_A_10 10
#define WING_A_11 11
#define WING_A_12 12
#define WING_A_13 13
#define WING_A_14 14
#define WING_A_15 15

#define WING_B_0 16
#define WING_B_1 17
#define WING_B_2 18
#define WING_B_3 19
#define WING_B_4 20
#define WING_B_5 21
#define WING_B_6 22
#define WING_B_7 23
#define WING_B_8 24
#define WING_B_9 25
#define WING_B_10 26
#define WING_B_11 27
#define WING_B_12 28
#define WING_B_13 29
#define WING_B_14 30
#define WING_B_15 31
        
#define WING_C_0 32
#define WING_C_1 33
#define WING_C_2 34
#define WING_C_3 35
#define WING_C_4 36
#define WING_C_5 37
#define WING_C_6 38
#define WING_C_7 39
#define WING_C_8 40
#define WING_C_9 41
#define WING_C_10 42
#define WING_C_11 43
#define WING_C_12 44
#define WING_C_13 45
#define WING_C_14 46
#define WING_C_15 47


#define SPI_FLASH_SEL_PIN FPGA_PIN_FLASHCS

#endif
