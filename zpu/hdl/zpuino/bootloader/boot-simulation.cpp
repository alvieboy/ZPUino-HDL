#include "zpuino.h"
#include <stdarg.h>

#define BOOTLOADER_SIZE 0x1000
#define STACKTOP (BOARD_MEMORYSIZE - 0x8)

# define FPGA_SS_B 40
# undef SPI_FLASH_SEL_PIN
# define SPI_FLASH_SEL_PIN FPGA_SS_B

unsigned int _memreg[4];



extern "C" void (*ivector)(void);

void spi_disable()
{
	digitalWriteS<SPI_FLASH_SEL_PIN,HIGH>::apply();
}

static inline void spi_enable()
{
	digitalWriteS<SPI_FLASH_SEL_PIN,LOW>::apply();
}

static inline void spiwrite(unsigned int i)
{
	SPIDATA=i;
}


void __attribute__((noreturn)) spi_copy()
{
	// Make sure we are on top of stack. We can safely discard everything
#ifdef VERBOSE_LOADER
	printstring("Starting sketch\r\n");
#endif
//	UARTCTL &= ~(BIT(UARTEN));

	__asm__("im %0\n"
			"popsp\n"
			"im spi_copy_impl\n"
			"poppc\n"
			:
			:"i"(STACKTOP)
		   );
	while (1) {}
}

extern "C" void __attribute__((noreturn)) spi_copy_impl()
{
	ivector = (void (*)(void))0x100c;
	__asm__("im %0\n"
			"popsp\n"
			"im __sketch_start\n"
			"poppc\n"
			:
			: "i" (STACKTOP));
	while(1) {}
}


extern "C" void _zpu_interrupt()
{
}

void configure_pins()
{
	GPIOTRIS(0)=0xFFFFFFFF; // All inputs
	GPIOTRIS(1)=0xFFFFFFFF; // All inputs
	GPIOTRIS(2)=0xFFFFFFFF; // All inputs
	GPIOTRIS(3)=0xFFFFFFFF; // All inputs

	GPIOPPSOUT( 4 ) = IOPIN_SPI_SCK;
	GPIOPPSOUT( 3 ) = IOPIN_SPI_MOSI;
	GPIOPPSIN( IOPIN_SPI_MISO ) = 2;

	GPIOPPSMODE(0) = BIT(4)|BIT(3);

	pinModeS<IOPIN_SPI_MOSI,OUTPUT>::apply();
	pinModeS<IOPIN_SPI_SCK,OUTPUT>::apply();
	pinModeS<IOPIN_SPI_MISO,INPUT>::apply();

	pinModeS<FPGA_SS_B,OUTPUT>::apply();

	spi_disable();
	spi_enable();
	spiwrite(0xaa);
	spi_disable();

	// Read ID
	spi_enable();
	spiwrite(0x9F);
	spiwrite(0x00);
	spiwrite(0x00);
	spiwrite(0x00);
	spi_disable();

}

extern "C" int main(int argc,char**argv)
{
//	ivector = &_zpu_interrupt;
	SPICTL=BIT(SPICPOL)|BIT(SPICP0)|BIT(SPISRE)|BIT(SPIEN)|BIT(SPIBLOCK);

	configure_pins();

	UARTCTL = BAUDRATEGEN(1000000) | BIT(UARTEN);
	INTRCTL=1;
	CRC16POLY = 0x8408; // CRC16-CCITT
	SPICTL=BIT(SPICPOL)|BIT(SPICP0)|BIT(SPISRE)|BIT(SPIEN);

	spi_copy();
}
