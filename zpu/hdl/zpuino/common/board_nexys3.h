#ifndef __BOARD_H__
#define __BOARD_H__

#define CLK_FREQ 100000000UL

#define SPIOFFSET 0x00000000

#define BOARD_SPI_DIVIDER BIT(SPICP1)

#define IOBASE 0x8000000
#define IO_SLOT_OFFSET_BIT 23

#define FPGA_PMOD_JA_0 0
#define FPGA_PMOD_JA_1 1
#define FPGA_PMOD_JA_2 2
#define FPGA_PMOD_JA_3 3
#define FPGA_PMOD_JA_4 4
#define FPGA_PMOD_JA_5 5
#define FPGA_PMOD_JA_6 6
#define FPGA_PMOD_JA_7 7

#define FPGA_PMOD_JB_0 8
#define FPGA_PMOD_JB_1 9
#define FPGA_PMOD_JB_2 10
#define FPGA_PMOD_JB_3 11
#define FPGA_PMOD_JB_4 12
#define FPGA_PMOD_JB_5 13
#define FPGA_PMOD_JB_6 14
#define FPGA_PMOD_JB_7 15

#define FPGA_PMOD_JC_0 16
#define FPGA_PMOD_JC_1 17
#define FPGA_PMOD_JC_2 18
#define FPGA_PMOD_JC_3 19
#define FPGA_PMOD_JC_4 20
#define FPGA_PMOD_JC_5 21
#define FPGA_PMOD_JC_6 22
#define FPGA_PMOD_JC_7 23

#define FPGA_PMOD_JD_0 24
#define FPGA_PMOD_JD_1 25
#define FPGA_PMOD_JD_2 26
#define FPGA_PMOD_JD_3 27
#define FPGA_PMOD_JD_4 28
#define FPGA_PMOD_JD_5 29
#define FPGA_PMOD_JD_6 30
#define FPGA_PMOD_JD_7 31


#define FPGA_7SEG_0 32
#define FPGA_7SEG_1 33
#define FPGA_7SEG_2 34
#define FPGA_7SEG_3 35
#define FPGA_7SEG_4 36
#define FPGA_7SEG_5 37
#define FPGA_7SEG_6 38
#define FPGA_7SEG_7 39
#define FPGA_7SEG_AN_0 40
#define FPGA_7SEG_AN_1 41
#define FPGA_7SEG_AN_2 42
#define FPGA_7SEG_AN_3 43

#define FPGA_BTNU 44
#define FPGA_BTND 45
#define FPGA_BTNL 46
#define FPGA_BTNR 47

#define SPI_FLASH_SEL_PIN 48

#define FPGA_LED_0 49
#define FPGA_LED_1 50
#define FPGA_LED_2 51
#define FPGA_LED_3 52
#define FPGA_LED_4 53
#define FPGA_LED_5 54
#define FPGA_LED_6 55
#define FPGA_LED_7 56

#define FPGA_SW_0 57
#define FPGA_SW_1 58
#define FPGA_SW_2 59
#define FPGA_SW_3 60
#define FPGA_SW_4 61
#define FPGA_SW_5 62
#define FPGA_SW_6 63
#define FPGA_SW_7 64

#endif
