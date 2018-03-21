#ifndef __BOARD_H__
#define __BOARD_H__

#define CLK_FREQ 100000000UL

#ifndef BOARD_MEMORYSIZE
#error Undefined board memory size
#endif

#define SPIOFFSET 0
#define SPI_FLASH_SEL_PIN 19

#define IOBASE 0x08000000
#define IO_SLOT_OFFSET_BIT 23

#define FPGA_PIN_D0    0
#define FPGA_PIN_D1    1
#define FPGA_PIN_D2    2
#define FPGA_PIN_D3    3
#define FPGA_PIN_D4    4
#define FPGA_PIN_D5    5
#define FPGA_PIN_D6    6
#define FPGA_PIN_D7    7
#define FPGA_PIN_D8    8
#define FPGA_PIN_D9    9
#define FPGA_PIN_D10    10
#define FPGA_PIN_D11    11
#define FPGA_PIN_D12    12
#define FPGA_PIN_D13    13

#define FPGA_PIN_A0    14
#define FPGA_PIN_A1    15
#define FPGA_PIN_A2    16

#define FPGA_PIN_LED_G 17
#define FPGA_PIN_LED_R 18

#endif
