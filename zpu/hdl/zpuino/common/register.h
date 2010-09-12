#ifndef __REGISTER_H__
#define __REGISTER_H__

#define CLK_FREQ 100000000ULL

#define IOBASE 0x8000
#define IO_SLOT_OFFSET_BIT 5
#define BIT(x) (1<<x)

#define IO_SLOT(x) (IOBASE + (x<<IO_SLOT_OFFSET_BIT))

#define REGISTER(SLOT, y) *(volatile unsigned int*)(SLOT + (y<<2))

#define SPIBASE  IO_SLOT(0)
#define UARTBASE IO_SLOT(1)
#define GPIOBASE IO_SLOT(2)
#define TIMERSBASE IO_SLOT(3)
#define INTRBASE IO_SLOT(4)

#define UARTDATA REGISTER(UARTBASE,0)
#define UARTCTL  REGISTER(UARTBASE,1)

#define SPICTL  REGISTER(SPIBASE,0)
#define SPIDATA REGISTER(SPIBASE,1)

#define GPIODATA  REGISTER(GPIOBASE,0)
#define GPIOTRIS  REGISTER(GPIOBASE,1)

#define TMR0CTL  REGISTER(TIMERSBASE,0)
#define TMR0CNT  REGISTER(TIMERSBASE,1)
#define TMR0CMP  REGISTER(TIMERSBASE,2)
#define TIMERTSC REGISTER(TIMERSBASE,3)
#define TMR0OCR  REGISTER(TIMERSBASE,3) /* Same as TSC */
#define TMR1CTL  REGISTER(TIMERSBASE,4)
#define TMR1CNT  REGISTER(TIMERSBASE,5)
#define TMR1CMP  REGISTER(TIMERSBASE,6)
#define TMR1OCR  REGISTER(TIMERSBASE,7)

#define INTRCTL  REGISTER(INTRBASE,0)

/* Timer CTL bits */

#define TCTLENA 0 /* Timer Enable */
#define TCTLCCM 1 /* Clear on Compare Match */
#define TCTLDIR 2 /* Direction */
#define TCTLIEN 3 /* Interrupt enable */
#define TCTLCP0 4 /* Clock prescaler bit 0 */
#define TCTLCP1 5 /* Clock prescaler bit 1 */
#define TCTLCP2 6 /* Clock prescaler bit 2 */
#define TCTLIF  7 /* Interrupt flag */
#define TCTLOCE 8 /* Output compare enable */

/* SPI bits */
#define SPIREADY 0 /* SPI ready */
#define SPICP0   1 /* Clock prescaler bit 0 */
#define SPICP1   2 /* Clock prescaler bit 1 */
#define SPICPOL  3 /* Clock polarity */
#define SPISRE   4 /* Sample on Rising Edge */

/* Baud rate computation */

#define BAUDRATEGEN(x) ((CLK_FREQ/(x))/4)

#endif
