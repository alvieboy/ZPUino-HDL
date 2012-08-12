#ifndef __BOARD_H__
#define __BOARD_H__

#define CLK_FREQ 90000000UL
#ifndef BOARD_MEMORYSIZE
//#define BOARD_MEMORYSIZE 0x8000
#error missing memory size
#endif

#define SPIOFFSET 0x00000000

#define BOARD_SPI_DIVIDER BIT(SPICP1)

#define IOBASE 0x08000000
#define IO_SLOT_OFFSET_BIT 23

/* J1 connector */
#define FPGA_PIN_B4 0
#define FPGA_PIN_A4 1
#define FPGA_PIN_D5 2
#define FPGA_PIN_C5 3
/* J2 connector */
#define FPGA_PIN_A6 4
#define FPGA_PIN_B6 5
#define FPGA_PIN_E7 6
#define FPGA_PIN_F7 7
/* J4 connector */
#define FPGA_PIN_D7 8
#define FPGA_PIN_C7 9
#define FPGA_PIN_F8 10
#define FPGA_PIN_E8 11
/* SW switches */
#define FPGA_PIN_L13 12
#define FPGA_PIN_L14 13
#define FPGA_PIN_H18 14
#define FPGA_PIN_N17 15
/* SPI CS line */
#define FPGA_PIN_U3  16
/* FX2 IO connector (21 to 35) */
#define FPGA_PIN_A13 17
#define FPGA_PIN_B13 18
#define FPGA_PIN_A14 19
#define FPGA_PIN_B14 20
#define FPGA_PIN_C14 21
#define FPGA_PIN_D14 22
#define FPGA_PIN_A16 23
#define FPGA_PIN_B16 24
#define FPGA_PIN_E13 25
#define FPGA_PIN_C4  26
#define FPGA_PIN_B11 27
#define FPGA_PIN_A11 28
#define FPGA_PIN_A8 29
#define FPGA_PIN_G9 30
#define FPGA_PIN_C3 31
/* LEDs */
#define FPGA_PIN_F12 32
#define FPGA_PIN_E12 33
#define FPGA_PIN_E11 34
#define FPGA_PIN_F11 35
#define FPGA_PIN_C11 36
#define FPGA_PIN_D11 37
#define FPGA_PIN_E9 38
#define FPGA_PIN_F9 39
/* LCD */
#define FPGA_PIN_R15 40 /* LCD_D4 */
#define FPGA_PIN_R16 41 /* LCD_D5 */
#define FPGA_PIN_P17 42 /* LCD_D6 */
#define FPGA_PIN_M15 43 /* LCD_D7 */
#define FPGA_PIN_L18 44 /* LCD_RS */
#define FPGA_PIN_L17 45 /* LCD_RW */
#define FPGA_PIN_M18 46 /* LCD_E  */
/* AMP shdn */
#define FPGA_PIN_P7  47
/* Rotary encoder */
#define FPGA_PIN_K18 48
#define FPGA_PIN_G18 49
#define FPGA_PIN_V16 50

/* AD_CONV */
#define FPGA_PIN_P11 51
/* DAC_CS */
#define FPGA_PIN_N8 52
/* AMP_CS */
#define FPGA_PIN_N7 53

//#define FPGA_PIN_D16 39


// #define FPGA_PIN_G14 0 // PS2_CLK
// #define FPGA_PIN_G13 1 // PS2_DATA

/* Aliases */

/* J1 connector */
#define FPGA_J1_0 FPGA_PIN_B4
#define FPGA_J1_1 FPGA_PIN_A4
#define FPGA_J1_2 FPGA_PIN_D5
#define FPGA_J1_3 FPGA_PIN_C5
/* J2 connector */
#define FPGA_J2_0 FPGA_PIN_A6
#define FPGA_J2_1 FPGA_PIN_B6
#define FPGA_J2_2 FPGA_PIN_E7
#define FPGA_J2_3 FPGA_PIN_F7
/* J4 connector */
#define FPGA_J4_0 FPGA_PIN_D7
#define FPGA_J4_1 FPGA_PIN_C7
#define FPGA_J4_2 FPGA_PIN_F8
#define FPGA_J4_3 FPGA_PIN_E8
/* SW switches */
#define FPGA_SW_0 FPGA_PIN_L13
#define FPGA_SW_1 FPGA_PIN_L14
#define FPGA_SW_2 FPGA_PIN_H18
#define FPGA_SW_3 FPGA_PIN_N17
/* FX2 IO connector (21 to 35) */
#define FPGA_FXIO_21 FPGA_PIN_A13 
#define FPGA_FXIO_22 FPGA_PIN_B13 
#define FPGA_FXIO_23 FPGA_PIN_A14 
#define FPGA_FXIO_24 FPGA_PIN_B14 
#define FPGA_FXIO_25 FPGA_PIN_C14 
#define FPGA_FXIO_26 FPGA_PIN_D14 
#define FPGA_FXIO_27 FPGA_PIN_A16 
#define FPGA_FXIO_28 FPGA_PIN_B16 
#define FPGA_FXIO_29 FPGA_PIN_E13 
#define FPGA_FXIO_30 FPGA_PIN_C4  
#define FPGA_FXIO_31 FPGA_PIN_B11 
#define FPGA_FXIO_32 FPGA_PIN_A11 
#define FPGA_FXIO_33 FPGA_PIN_A8 
#define FPGA_FXIO_34 FPGA_PIN_G9 
#define FPGA_FXIO_35 FPGA_PIN_C3 
/* LEDs */
#define FPGA_LED_0 FPGA_PIN_F12
#define FPGA_LED_1 FPGA_PIN_E12
#define FPGA_LED_2 FPGA_PIN_E11
#define FPGA_LED_3 FPGA_PIN_F11
#define FPGA_LED_4 FPGA_PIN_C11
#define FPGA_LED_5 FPGA_PIN_D11
#define FPGA_LED_6 FPGA_PIN_E9
#define FPGA_LED_7 FPGA_PIN_F9
/* LCD */
#define FPGA_LCD_D4 FPGA_PIN_R15 
#define FPGA_LCD_D5 FPGA_PIN_R16 
#define FPGA_LCD_D6 FPGA_PIN_P17 
#define FPGA_LCD_D7 FPGA_PIN_M15 
#define FPGA_LCD_RS FPGA_PIN_L18 
#define FPGA_LCD_RW FPGA_PIN_L17 
#define FPGA_LCD_E  FPGA_PIN_M18 
/* AMP shdn */
#define FPGA_AMP_SHDN FPGA_PIN_P7 
/* Rotary encoder */
#define FPGA_ROT_A FPGA_PIN_K18 
#define FPGA_ROT_B FPGA_PIN_G18 
#define FPGA_ROT_C FPGA_PIN_V16 

/* AD_CONV */
#define FPGA_AD_CONV FPGA_PIN_P11 
/* DAC_CS */
#define FPGA_DAC_CS FPGA_PIN_N8 
/* AMP_CS */
#define FPGA_AMP_CS FPGA_PIN_N7 


#define SPI_FLASH_SEL_PIN FPGA_PIN_U3




#endif
