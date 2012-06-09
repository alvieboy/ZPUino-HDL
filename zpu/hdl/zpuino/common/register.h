#ifndef __REGISTER_H__
#define __REGISTER_H__

#if defined( __ZPUINO_S3E_EVAL__ )
# include "board_s3e_eval.h"
#elif defined( __ZPUINO_PAPILIO_ONE__ )
# include "board_papilio_one.h"
#elif defined( __ZPUINO_PAPILIO_PLUS__ )
# include "board_papilio_plus.h"
#elif defined( __ZPUINO_NEXYS2__ )
# include "board_nexys2.h"
#elif defined( __ZPUINO_OHO_GODIL__ )
# include "board_oho_godil.h"
#else
#  error Unknown board.
# endif

#ifndef ASSEMBLY
typedef volatile unsigned int* register_t;
#endif

#define SPIISBLOCKING 1

#define BIT(x) (1<<x)

#define IO_SLOT(x) (IOBASE + (x<<IO_SLOT_OFFSET_BIT))

#define REGISTER(SLOT, y) *(volatile unsigned int*)(SLOT + (y<<2))

#define SPIBASE  IO_SLOT(0)
#define UARTBASE IO_SLOT(1)
#define GPIOBASE IO_SLOT(2)
#define TIMERSBASE IO_SLOT(3)
#define INTRBASE IO_SLOT(4)
#define SIGMADELTABASE IO_SLOT(5)
#define USERSPIBASE IO_SLOT(6)
#define CRC16BASE IO_SLOT(7)

#define ROFF_UARTDATA   0
#define ROFF_UARTCTL    1
#define ROFF_UARTSTATUS 1

#define UARTDATA    REGISTER(UARTBASE,ROFF_UARTDATA)
#define UARTCTL     REGISTER(UARTBASE,ROFF_UARTCTL)
#define UARTSTATUS  REGISTER(UARTBASE,ROFF_UARTSTATUS)

#define ROFF_SPICTL  0
#define ROFF_SPIDATA 1

#define SPICTL  REGISTER(SPIBASE,ROFF_SPICTL)
#define SPIDATA REGISTER(SPIBASE,ROFF_SPIDATA)

#define GPIODATA(x)  REGISTER(GPIOBASE,x)
#define GPIOTRIS(x)  REGISTER(GPIOBASE,4+x)
#define GPIOPPSMODE(x)  REGISTER(GPIOBASE,8+x)

#define GPIOPPSOUT(x)  REGISTER(GPIOBASE,(128 + x))
#define GPIOPPSIN(x)  REGISTER(GPIOBASE,(256 + x))

#define ROFF_TMR0CTL  0
#define ROFF_TMR0CNT  1
#define ROFF_TMR0CMP  2
#define ROFF_TIMERTSC 3
//#define ROFF_TMR0OCR  3
#define ROFF_TMR1CTL  64
#define ROFF_TMR1CNT  65
#define ROFF_TMR1CMP  66
//#define ROFF_TMR1OCR  67



#define TMR0CTL  REGISTER(TIMERSBASE,0)
#define TMR0CNT  REGISTER(TIMERSBASE,1)
#define TMR0CMP  REGISTER(TIMERSBASE,2)
#define TIMERTSC REGISTER(TIMERSBASE,3)

// PWM for timer 0
#define TMR0PWMLOW(x) REGISTER(TIMERSBASE, 32+(4*x))
#define TMR0PWMHIGH(x) REGISTER(TIMERSBASE, 33+(4*x))
#define TMR0PWMCTL(x) REGISTER(TIMERSBASE, 34+(4*x))

#define TMR1CTL  REGISTER(TIMERSBASE,64)
#define TMR1CNT  REGISTER(TIMERSBASE,65)
#define TMR1CMP  REGISTER(TIMERSBASE,66)

// PWM for timer 1
#define TMR1PWMLOW(x) REGISTER(TIMERSBASE, 96+(4*x))
#define TMR1PWMHIGH(x) REGISTER(TIMERSBASE, 97+(4*x))
#define TMR1PWMCTL(x) REGISTER(TIMERSBASE, 98+(4*x))

#define INTRCTL  REGISTER(INTRBASE,0)
#define INTRMASK  REGISTER(INTRBASE,1)
#define INTRLEVEL  REGISTER(INTRBASE,2)

#define SIGMADELTACTL   REGISTER(SIGMADELTABASE,0)
#define SIGMADELTADATA  REGISTER(SIGMADELTABASE,1)

#define USPICTL  REGISTER(USERSPIBASE,0)
#define USPIDATA REGISTER(USERSPIBASE,1)

#define ROFF_CRC16ACC  0
#define ROFF_CRC16POLY 1
#define ROFF_CRC16APP  2
#define ROFF_CRC16AM1  4
#define ROFF_CRC16AM2  5

#define CRC16ACC  REGISTER(CRC16BASE,0)
#define CRC16POLY REGISTER(CRC16BASE,1)
#define CRC16APP  REGISTER(CRC16BASE,2)
#define CRC16AM1  REGISTER(CRC16BASE,4)
#define CRC16AM2  REGISTER(CRC16BASE,5)

#define UARTEN 16 /* Uart enable */

/* Timer CTL bits */

#define TCTLENA 0 /* Timer Enable */
#define TCTLCCM 1 /* Clear on Compare Match */
#define TCTLDIR 2 /* Direction */
#define TCTLIEN 3 /* Interrupt enable */
#define TCTLCP0 4 /* Clock prescaler bit 0 */
#define TCTLCP1 5 /* Clock prescaler bit 1 */
#define TCTLCP2 6 /* Clock prescaler bit 2 */
#define TCTLIF  7 /* Interrupt flag */
#define TCTUPDP0 9 /* Update policy */
#define TCTUPDP1 10 /* Update policy */

#define TPWMEN 0 /* PWM enabled */

#define TCTL_UPDATE_NOW (0<<TCTUPDP0)
#define TCTL_UPDATE_ZERO_SYNC (1<<TCTUPDP0)
#define TCTL_UPDATE_LATER (2<<TCTUPDP0)

/* SPI bits */
#define SPIREADY 0 /* SPI ready */
#define SPICP0   1 /* Clock prescaler bit 0 */
#define SPICP1   2 /* Clock prescaler bit 1 */
#define SPICP2   3 /* Clock prescaler bit 2 */
#define SPICPOL  4 /* Clock polarity */
#define SPISRE   5 /* Sample on Rising Edge */
#define SPIEN    6 /* SPI Enabled (gpio acquire) */
#define SPIBLOCK 7
#define SPITS0   8
#define SPITS1   9

/* Sigma-Delta bits */
#define SDENA0    0 /* Sigma-delta enable */
#define SDENA1    1
#define SDLE      2 /* Little-endian */

/* Baud rate computation */

#define BAUDRATEGEN(x) ((CLK_FREQ/(x))/16)-1

#define INPUT 1
#define OUTPUT 0

#define HIGH 1
#define LOW 0

/* PPS configuration - output */

#define IOPIN_SIGMADELTA0 0
#define IOPIN_TIMER0_OC   1
#define IOPIN_TIMER1_OC   2
#define IOPIN_USPI_MOSI   3
#define IOPIN_USPI_SCK    4
#define IOPIN_SIGMADELTA1 5

/* PPS configuration - input */
#define IOPIN_USPI_MISO   0

/* Current interrupts (might not be implemented) */

#define INTRLINE_TIMER0 3
#define INTRLINE_TIMER1 4
#define INTRLINE_EXT1 16
#define INTRLINE_EXT2 17

#endif
