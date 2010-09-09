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

#define TIMERTSC REGISTER(TIMERSBASE,0)
#define TMR0CTL  REGISTER(TIMERSBASE,1)
#define TMR0CNT  REGISTER(TIMERSBASE,2)
#define TMR0CMP  REGISTER(TIMERSBASE,3)

#define INTRCTL  REGISTER(INTRBASE,0)

/* Timer CTL bits */

#define TCTLENA 0
#define TCTLCCM 1
#define TCTLDIR 2
#define TCTLIEN 3
#define TCTLCP0 4
#define TCTLCP1 5
#define TCTLCP2 6
#define TCTLIF  7
/* SPI bits */

#define SPICP0   1
#define SPICP1   2
#define SPICPOL  3
#define SPIREADY  0
/* Baud rate computation */

#define BAUDRATEGEN(x) ((CLK_FREQ/(x))/4)

#endif
