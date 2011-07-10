#include "zputypes.h"
#include <stdio.h>
#include "zpuinointerface.h"

static unsigned short timer_cnt;
static unsigned short timer_match;
static unsigned int timer_prescaleCount;
static unsigned int timer_prescaler;

#define TCTLENA 0 /* Timer Enable */
#define TCTLCCM 1 /* Clear on Compare Match */
#define TCTLDIR 2 /* Direction */
#define TCTLIEN 3 /* Interrupt enable */
#define TCTLCP0 4 /* Clock prescaler bit 0 */
#define TCTLCP1 5 /* Clock prescaler bit 1 */
#define TCTLCP2 6 /* Clock prescaler bit 2 */
#define TCTLIF  7 /* Interrupt flag */
#define TCTLOCE 8 /* Output compare enable */

#define BIT(x) (1<<x)

extern void zpudebug(const char *fmt,...);






static unsigned int ctrl;

void timer_init()
{
	timer_cnt=0;
	timer_match=0;
	timer_prescaleCount=1;
	ctrl = 0;
	timer_prescaler=1;
}

void timer_tick(unsigned delta)
{
	if (likely(ctrl & BIT(TCTLENA) )) {
		while (delta--) {
			if (unlikely(timer_prescaleCount==0)) {

				if (unlikely(timer_cnt>=timer_match)) {
					//printf("Timer match %04x\n",timer_cnt);

					if (ctrl & BIT(TCTLIEN) ) {
						//  printf("# Interrupting\n");
						ctrl |= BIT(TCTLIF);
						//do_interrupt=1;
						zpuino_request_interrupt(0);
					}

					if (ctrl & BIT(TCTLCCM)) {
						//printf("Timer clear\n");
						timer_cnt=0;
						return;
					}
				}

				if (likely(ctrl & BIT(TCTLDIR)))
					timer_cnt++;
				else
					timer_cnt--;
				timer_prescaleCount = timer_prescaler;
			}

			if (likely(timer_prescaleCount>0)) {
				timer_prescaleCount--;
			}
		}
	}
}

unsigned int timer_read_ctrl( unsigned int address )
{
	return ctrl;
}
unsigned int timer_read_cnt( unsigned int address )
{
	return timer_cnt;
}
unsigned int timer_read_cmp( unsigned int address )
{
	return timer_match;
}


void timer_write( unsigned int address, unsigned int value)
{
	//zpudebug("Timer write, 0x%08x = 0x%08x\n",address,value);

	switch(address & 0xF) {
	case 0:
		ctrl = value;
       /*
		 printf("Timer bits: EN %d CCM %d DIR %d IEN %d\n",
			   !!(ctrl & BIT(TCTLENA)),
			   !!(ctrl & BIT(TCTLCCM)),
			   !!(ctrl & BIT(TCTLDIR)),
			   !!(ctrl & BIT(TCTLIEN)));
        */
		switch (bit_range(ctrl,6,4)) {
		case 0:
			timer_prescaler=0;
			break;
		case 1:
			timer_prescaler=1;
			break;
		case 2:
			timer_prescaler=2;
			break;
		case 3:
			timer_prescaler=4;
			break;
		case 4:
			timer_prescaler=8;
			break;
		case 5:
			timer_prescaler=32;
			break;
		case 6:
			timer_prescaler=128;
			break;
		case 7:
			timer_prescaler=512;
			break;
		}
		//printf("Timer prescaler is now %d\n",timer_prescaler);
		timer_prescaleCount=0;

		break;
	case 4:
		// Counter
		//printf("# Timer: set counter to %04x\n",value);
		timer_cnt = value & 0xffff;
		break;
	case 8:
		// Compare
		//printf("Timer: set compare to %04x\n",value);
		timer_match = value & 0xffff;
		break;
	case 12:
		// Compare
		break;
	}
}

unsigned timer_read_tsc(unsigned address)
{
    return zpuino_get_tick_count();
}

unsigned timers_io_read_handler(unsigned address)
{
	MAPREGR(0,timer_read_ctrl);
	MAPREGR(1,timer_read_cnt);
	MAPREGR(2,timer_read_cmp);
    MAPREGR(3,timer_read_tsc);
	ERRORREG();

	return 0;
}

void timers_io_write_handler(unsigned address, unsigned value)
{
	MAPREGW(0,timer_write);
	MAPREGW(1,timer_write);
	MAPREGW(2,timer_write);
	MAPREGW(3,timer_write);
	ERRORREG();
}

int initialize_device(int argc, char **argv)
{
	zpuino_request_tick( &timer_tick );
	return 0;
}

static zpuino_device_t dev = {
    .name = "timer",
	.init = initialize_device,
	.read = timers_io_read_handler,
	.write = timers_io_write_handler,
	.post_init = NULL
};

static void ZPUINOINIT zpuinotimer_init()
{
	zpuino_register_device(&dev);
}
