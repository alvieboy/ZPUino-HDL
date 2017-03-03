#ifndef __BOARD_H__
#define __BOARD_H__

#define CLK_FREQ 96000000UL

/* LX9 bitfile is 0x5327C in size */

#define SPIOFFSET 0x60000

#ifndef BOARD_MEMORYSIZE
#error Undefined board memory size
#endif

#define BOARD_SPI_DIVIDER BIT(SPICP0)

#define IOBASE 0x08000000
#define IO_SLOT_OFFSET_BIT 23

#define __SST_FLASH__

// Wing1 Column A
// Wing1 Column A
#define FPGA_PIN_P85 0
#define FPGA_PIN_P83 1
#define FPGA_PIN_P81 2
#define FPGA_PIN_P79 3
#define FPGA_PIN_P75 4
#define FPGA_PIN_P67 5
#define FPGA_PIN_P59 6
#define FPGA_PIN_P57 7
#define FPGA_PIN_P55 8
#define FPGA_PIN_P48 9
#define FPGA_PIN_P46 10
#define FPGA_PIN_P44 11
#define FPGA_PIN_P41 12
#define FPGA_PIN_P35 13
#define FPGA_PIN_P33 14
#define FPGA_PIN_P30 15

//Wing1 Column B
#define FPGA_PIN_P87 16
#define FPGA_PIN_P84 17
#define FPGA_PIN_P82 18
#define FPGA_PIN_P80 19
#define FPGA_PIN_P78 20
#define FPGA_PIN_P74 21
#define FPGA_PIN_P66 22
#define FPGA_PIN_P58 23
#define FPGA_PIN_P56 24
#define FPGA_PIN_P51 25
#define FPGA_PIN_P47 26
#define FPGA_PIN_P45 27
#define FPGA_PIN_P43 28
#define FPGA_PIN_P40 29
#define FPGA_PIN_P34 30
#define FPGA_PIN_P32 31

// Wing2 Column A
#define FPGA_PIN_P111 32
#define FPGA_PIN_P112 33
#define FPGA_PIN_P114 34
#define FPGA_PIN_P115 35
#define FPGA_PIN_P116 36
#define FPGA_PIN_P117 37
#define FPGA_PIN_P118 38
#define FPGA_PIN_P119 39
#define FPGA_PIN_P120 40
#define FPGA_PIN_P121 41
#define FPGA_PIN_P123 42
#define FPGA_PIN_P124 43
#define FPGA_PIN_P126 44
#define FPGA_PIN_P127 45
#define FPGA_PIN_P131 46
#define FPGA_PIN_P132 47

// Other pins
#define FPGA_PIN_P24 48
#define FPGA_LED_PIN 49

#define FPGA_PIN_FLASHCS     FPGA_PIN_P24

#define SPI_FLASH_SEL_PIN FPGA_PIN_FLASHCS

/* WING configuration */

#define WING_A_0  FPGA_PIN_P85
#define WING_A_1  FPGA_PIN_P83
#define WING_A_2  FPGA_PIN_P81
#define WING_A_3  FPGA_PIN_P79
#define WING_A_4  FPGA_PIN_P75
#define WING_A_5  FPGA_PIN_P67
#define WING_A_6  FPGA_PIN_P59
#define WING_A_7  FPGA_PIN_P57
#define WING_A_8  FPGA_PIN_P55
#define WING_A_9  FPGA_PIN_P48
#define WING_A_10 FPGA_PIN_P46
#define WING_A_11 FPGA_PIN_P44
#define WING_A_12 FPGA_PIN_P41
#define WING_A_13 FPGA_PIN_P35
#define WING_A_14 FPGA_PIN_P33
#define WING_A_15 FPGA_PIN_P30

#define WING_B_0  FPGA_PIN_P87
#define WING_B_1  FPGA_PIN_P84
#define WING_B_2  FPGA_PIN_P82
#define WING_B_3  FPGA_PIN_P80
#define WING_B_4  FPGA_PIN_P78
#define WING_B_5  FPGA_PIN_P74
#define WING_B_6  FPGA_PIN_P66
#define WING_B_7  FPGA_PIN_P58
#define WING_B_8  FPGA_PIN_P56
#define WING_B_9  FPGA_PIN_P51
#define WING_B_10 FPGA_PIN_P47
#define WING_B_11 FPGA_PIN_P45
#define WING_B_12 FPGA_PIN_P43
#define WING_B_13 FPGA_PIN_P40
#define WING_B_14 FPGA_PIN_P34
#define WING_B_15 FPGA_PIN_P32
        
#define WING_C_0  FPGA_PIN_P111
#define WING_C_1  FPGA_PIN_P112
#define WING_C_2  FPGA_PIN_P114
#define WING_C_3  FPGA_PIN_P115
#define WING_C_4  FPGA_PIN_P116
#define WING_C_5  FPGA_PIN_P117
#define WING_C_6  FPGA_PIN_P118
#define WING_C_7  FPGA_PIN_P119
#define WING_C_8  FPGA_PIN_P120
#define WING_C_9  FPGA_PIN_P121
#define WING_C_10 FPGA_PIN_P123
#define WING_C_11 FPGA_PIN_P124
#define WING_C_12 FPGA_PIN_P126
#define WING_C_13 FPGA_PIN_P127
#define WING_C_14 FPGA_PIN_P131
#define WING_C_15 FPGA_PIN_P132

#endif
