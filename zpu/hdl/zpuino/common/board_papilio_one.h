#ifndef __BOARD_H__
#define __BOARD_H__

#define CLK_FREQ 96000000ULL
#define BOARD_MEMORYSIZE 0x4000
#define SPIOFFSET 0x00040000

#define IOBASE 0x4000
#define IO_SLOT_OFFSET_BIT 11


// Wing1 Column A
#define FPGA_PIN_P18 0
#define FPGA_PIN_P23 1
#define FPGA_PIN_P26 2
#define FPGA_PIN_P33 3
#define FPGA_PIN_P35 4
#define FPGA_PIN_P40 5
#define FPGA_PIN_P53 6
#define FPGA_PIN_P57 7
#define FPGA_PIN_P60 8
#define FPGA_PIN_P62 9
#define FPGA_PIN_P65 10
#define FPGA_PIN_P67 11
#define FPGA_PIN_P70 12
#define FPGA_PIN_P79 13
#define FPGA_PIN_P84 14
#define FPGA_PIN_P86 15

//Wing1 Column B
#define FPGA_PIN_P89 16
#define FPGA_PIN_P83 17
#define FPGA_PIN_P78 18
#define FPGA_PIN_P71 19
#define FPGA_PIN_P68 20
#define FPGA_PIN_P66 21
#define FPGA_PIN_P63 22
#define FPGA_PIN_P61 23
#define FPGA_PIN_P58 24
#define FPGA_PIN_P54 25
#define FPGA_PIN_P41 26
#define FPGA_PIN_P36 27
#define FPGA_PIN_P34 28
#define FPGA_PIN_P32 29
#define FPGA_PIN_P25 30
#define FPGA_PIN_P22 31

// Wing2 Column A
#define FPGA_PIN_P91 32
#define FPGA_PIN_P92 33
#define FPGA_PIN_P94 34
#define FPGA_PIN_P95 35
#define FPGA_PIN_P98 36
#define FPGA_PIN_P2  37
#define FPGA_PIN_P3  38
#define FPGA_PIN_P4  39
#define FPGA_PIN_P5  40
#define FPGA_PIN_P9  41
#define FPGA_PIN_P10 42
#define FPGA_PIN_P11 43
#define FPGA_PIN_P12 44
#define FPGA_PIN_P15 45
#define FPGA_PIN_P16 46
#define FPGA_PIN_P17 47

// Other pins
#define FPGA_PIN_P88 48
#define FPGA_PIN_P44 49
#define FPGA_PIN_P90 50
#define FPGA_PIN_P50 51
#define FPGA_PIN_P24 52
#define FPGA_PIN_P27 53

#define FPGA_PIN_UART_RX     FPGA_PIN_P88
#define FPGA_PIN_UART_TX     FPGA_PIN_P90
#define FPGA_PIN_SPI_MISO    FPGA_PIN_P44
#define FPGA_PIN_SPI_MOSI    FPGA_PIN_P27
#define FPGA_PIN_SPI_SCK     FPGA_PIN_P50
#define FPGA_PIN_FLASHCS     FPGA_PIN_P24

#define SPI_FLASH_SEL_PIN FPGA_PIN_FLASHCS

#endif
