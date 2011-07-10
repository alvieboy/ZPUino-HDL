#include "zpuinointerface.h"
#include <stdio.h>
#include "gpio.h"
#include <glib.h>

static unsigned int gpio_val[4];
static unsigned int gpio_tris[4];
GSList *watcher[4];

struct gpio_watcher
{
	unsigned int pinmask;
	unsigned int pin;
	gpio_notifier_callback_t callback;
	void *data;
};




int gpio_add_pin_notify(unsigned pin, gpio_notifier_callback_t callback, void*data)
{
	unsigned slot = pin / 32;
	unsigned offset = pin % 32;

	unsigned mask = 1<<offset;

	struct gpio_watcher *w = g_new(struct gpio_watcher,1);
	w->pinmask = mask;
	w->pin = pin;
	w->callback = callback;
	w->data = data;

	watcher[slot] = g_slist_append( watcher[slot], w);
	//fprintf(stderr,"GPIO: add watcher to slot %d, pin %d\n", slot,pin);
	return 0;
}

void gpio_check_watch(unsigned old_v, unsigned new_v, unsigned slot)
{
	//fprintf(stderr,"GPIO: watcher %d %p\n", slot, watcher[slot]);
	if (NULL==watcher[slot])
		return;

	unsigned xored = new_v ^ old_v;

	//fprintf(stderr,"GPIO check %08x -> %08x, mask is %08x\n", old_v, new_v, xored);

	if (0==xored)
		return;

	GSList *i;

	for (i=watcher[slot]; i; i = g_slist_next(i)) {
		struct gpio_watcher *w = i->data;
		//fprintf(stderr,"GPIO: pinmask %08x, xored %08x\n", w->pinmask, xored);
		if (w->pinmask & xored) {
			w->callback(w->pin, !!(w->pinmask & new_v),w->data);
		}
	}
}

void gpio_set_pin(unsigned pin, unsigned value)
{
	unsigned index=pin/32;
	unsigned mask=1<<(pin%32);

	gpio_val[index] &= ~mask;

//	fprintf(stderr,"PIN changed, %d to %d\n", pin, value);

	if (!value)
		return;
	gpio_val[index] |= mask;
}

unsigned int gpio_read(unsigned int address)
{
	return 0;
}


void gpio_write_val_0(unsigned int address, unsigned int val)
{
	gpio_check_watch(gpio_val[0],val,0);

	gpio_val[0]=val;
}

void gpio_write_val_1(unsigned int address, unsigned int val)
{
	gpio_check_watch(gpio_val[1],val,1);
	gpio_val[1]=val;
}

void gpio_write_val_2(unsigned int address, unsigned int val)
{
	gpio_check_watch(gpio_val[2],val,2);
	gpio_val[2]=val;
}

void gpio_write_val_3(unsigned int address, unsigned int val)
{
	gpio_check_watch(gpio_val[3],val,3);
	gpio_val[3]=val;
}

void gpio_write_tris_0(unsigned int address, unsigned int val)
{
    gpio_tris[0] = val;
}
void gpio_write_tris_1(unsigned int address, unsigned int val)
{
    gpio_tris[1] = val;
}
void gpio_write_tris_2(unsigned int address, unsigned int val)
{
    gpio_tris[2] = val;
}
void gpio_write_tris_3(unsigned int address, unsigned int val)
{
    gpio_tris[3] = val;
}

unsigned gpio_read_val_0(unsigned int address)
{
	return gpio_val[0];
}
unsigned gpio_read_val_1(unsigned int address)
{
	return gpio_val[1];
}
unsigned gpio_read_val_2(unsigned int address)
{
	return gpio_val[2];
}
unsigned gpio_read_val_3(unsigned int address)
{
	return gpio_val[3];
}

unsigned gpio_read_tris_0(unsigned int address)
{
	return gpio_tris[0];
}
unsigned gpio_read_tris_1(unsigned int address)
{
	return gpio_tris[1];
}
unsigned gpio_read_tris_2(unsigned int address)
{
	return gpio_tris[2];
}
unsigned gpio_read_tris_3(unsigned int address)
{
	return gpio_tris[3];
}



void gpio_write_pps_in(unsigned int address, unsigned int val)
{
}

void gpio_write_pps_out(unsigned int address, unsigned int val)
{
}

unsigned gpio_read_pps_in(unsigned int address)
{
	return 0;
}
unsigned gpio_read_pps_out(unsigned int address)
{
	return 0;
}

void gpio_write_ppsmode(unsigned int address, unsigned val)
{
}
unsigned gpio_read_ppsmode(unsigned int address)
{
	return 0;
}

void gpio_io_write_handler(unsigned address, unsigned value)
{
	//printf("GPIO write 0x%08x @ 0x%08x\n",value,address);

	if (IOREG(address)>=128) {
		return ;
	}

	MAPREGW(0, gpio_write_val_0);
	MAPREGW(1, gpio_write_val_1);
	MAPREGW(2, gpio_write_val_2);
	MAPREGW(3, gpio_write_val_3);

	MAPREGW(4, gpio_write_tris_0);
	MAPREGW(5, gpio_write_tris_1);
	MAPREGW(6, gpio_write_tris_2);
	MAPREGW(7, gpio_write_tris_3);

	MAPREGW(8, gpio_write_ppsmode);
	MAPREGW(9, gpio_write_ppsmode);
	MAPREGW(10, gpio_write_ppsmode);
	MAPREGW(11, gpio_write_ppsmode);

	
	ERRORREG();

			/*io_set_write_func( REGISTER(GPIOBASE,0), &gpio_write_val_0 );
	io_set_write_func( REGISTER(GPIOBASE,1), &gpio_write_val_1 );
	io_set_write_func( REGISTER(GPIOBASE,2), &gpio_write_val_2 );
	io_set_write_func( REGISTER(GPIOBASE,3), &gpio_write_val_3 );

	io_set_write_func( REGISTER(GPIOBASE,4), &gpio_write_tris_0 );
	io_set_write_func( REGISTER(GPIOBASE,5), &gpio_write_tris_1 );
	io_set_write_func( REGISTER(GPIOBASE,6), &gpio_write_tris_2 );
	io_set_write_func( REGISTER(GPIOBASE,7), &gpio_write_tris_3 );

	io_set_read_func( REGISTER(GPIOBASE,0), &gpio_read_val_0 );
	io_set_read_func( REGISTER(GPIOBASE,1), &gpio_read_val_1 );
	io_set_read_func( REGISTER(GPIOBASE,2), &gpio_read_val_2 );
	io_set_read_func( REGISTER(GPIOBASE,3), &gpio_read_val_3 );

	io_set_read_func( REGISTER(GPIOBASE,4), &gpio_read_tris_0 );
	io_set_read_func( REGISTER(GPIOBASE,5), &gpio_read_tris_1 );
	io_set_read_func( REGISTER(GPIOBASE,6), &gpio_read_tris_2 );
	io_set_read_func( REGISTER(GPIOBASE,7), &gpio_read_tris_3 );*/

}

unsigned gpio_io_read_handler(unsigned address)
{
	//printf("GPIO read @ 0x%08x\n",address);

	if (IOREG(address)>=128) {
		return 0;
	}

	MAPREGR(0, gpio_read_val_0);
	MAPREGR(1, gpio_read_val_1);
	MAPREGR(2, gpio_read_val_2);
	MAPREGR(3, gpio_read_val_3);

	MAPREGR(4, gpio_read_tris_0);
	MAPREGR(5, gpio_read_tris_1);
	MAPREGR(6, gpio_read_tris_2);
	MAPREGR(7, gpio_read_tris_3);

	MAPREGR(8, gpio_read_ppsmode);
	MAPREGR(9, gpio_read_ppsmode);
	MAPREGR(10, gpio_read_ppsmode);
	MAPREGR(11, gpio_read_ppsmode);

	ERRORREG();

	return 0;
}

static int initialize_device(int argc,char**argv)
{
	int i;
	for (i=0;i<4;i++) {
		watcher[i] = NULL;
	}
	return 0;
}

static gpio_class_t gpio_class = {
	.add_pin_notify = &gpio_add_pin_notify,
	.set_pin = &gpio_set_pin
};

static zpuino_device_t dev = {
	.name = "gpio",
	.init = initialize_device,
	.read = gpio_io_read_handler,
	.write = gpio_io_write_handler,
	.post_init = NULL,
	.class = &gpio_class
};

static void ZPUINOINIT gpio_init()
{
	zpuino_register_device(&dev);
}
