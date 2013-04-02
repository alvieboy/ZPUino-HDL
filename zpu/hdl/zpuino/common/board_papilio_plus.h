#ifndef __BOARD_H__
#define __BOARD_H__

#define CLK_FREQ 96000000UL

/* LX4 bitfile is 0x5327C in size */    

#define SPIOFFSET 0x54000

#ifndef BOARD_MEMORYSIZE
#error Undefined board memory size
#endif

#define BOARD_SPI_DIVIDER BIT(SPICP0)

#define IOBASE 0x08000000
#define IO_SLOT_OFFSET_BIT 23

#define __SST_FLASH__

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
#define FPGA_PIN_P85 16
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
#define FPGA_PIN_P24 48
#define FPGA_LED_PIN 49

#define FPGA_PIN_FLASHCS     FPGA_PIN_P24

#define SPI_FLASH_SEL_PIN FPGA_PIN_FLASHCS

/* WING configuration */

#define WING_A_0 FPGA_PIN_P18
#define WING_A_1 FPGA_PIN_P23
#define WING_A_2 FPGA_PIN_P26
#define WING_A_3 FPGA_PIN_P33
#define WING_A_4 FPGA_PIN_P35
#define WING_A_5 FPGA_PIN_P40
#define WING_A_6 FPGA_PIN_P53
#define WING_A_7 FPGA_PIN_P57
#define WING_A_8 FPGA_PIN_P60
#define WING_A_9 FPGA_PIN_P62
#define WING_A_10 FPGA_PIN_P65
#define WING_A_11 FPGA_PIN_P67
#define WING_A_12 FPGA_PIN_P70
#define WING_A_13 FPGA_PIN_P79
#define WING_A_14 FPGA_PIN_P84
#define WING_A_15 FPGA_PIN_P86

#define WING_B_0 FPGA_PIN_P85
#define WING_B_1 FPGA_PIN_P83
#define WING_B_2 FPGA_PIN_P78
#define WING_B_3 FPGA_PIN_P71
#define WING_B_4 FPGA_PIN_P68
#define WING_B_5 FPGA_PIN_P66
#define WING_B_6 FPGA_PIN_P63
#define WING_B_7 FPGA_PIN_P61
#define WING_B_8 FPGA_PIN_P58
#define WING_B_9 FPGA_PIN_P54
#define WING_B_10 FPGA_PIN_P41
#define WING_B_11 FPGA_PIN_P36
#define WING_B_12 FPGA_PIN_P34
#define WING_B_13 FPGA_PIN_P32
#define WING_B_14 FPGA_PIN_P25
#define WING_B_15 FPGA_PIN_P22
        
#define WING_C_0 FPGA_PIN_P91
#define WING_C_1 FPGA_PIN_P92
#define WING_C_2 FPGA_PIN_P94
#define WING_C_3 FPGA_PIN_P95
#define WING_C_4 FPGA_PIN_P98
#define WING_C_5 FPGA_PIN_P2
#define WING_C_6 FPGA_PIN_P3
#define WING_C_7 FPGA_PIN_P4
#define WING_C_8 FPGA_PIN_P5
#define WING_C_9 FPGA_PIN_P9
#define WING_C_10 FPGA_PIN_P10
#define WING_C_11 FPGA_PIN_P11
#define WING_C_12 FPGA_PIN_P12
#define WING_C_13 FPGA_PIN_P15
#define WING_C_14 FPGA_PIN_P16
#define WING_C_15 FPGA_PIN_P17

#endif
