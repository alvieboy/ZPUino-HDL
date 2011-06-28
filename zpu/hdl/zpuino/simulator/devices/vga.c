#include "zpuinointerface.h"
#include "config.h"
#include <stdio.h>

#ifdef HAVE_SDL

#include <SDL.h>

static SDL_Surface *screen;

void updater_thread()
{
	while (1) {
		SDL_Flip(screen);
		usleep(1000000/75);
	}
}

static pthread_t vgathread;
static pthread_attr_t vgathreadattr;

int initialize_device(int argc,char **argv)
{
	screen = SDL_SetVideoMode( 800, 600, 32, SDL_SWSURFACE );
	if (NULL==screen)
		return -1;

	// Add updater thread

	pthread_attr_init(&vgathreadattr);
	pthread_create(&vgathread,&vgathreadattr, updater_thread, NULL);

	return 0;
}

unsigned vga_io_read_handler(unsigned address)
{
}

void vga_io_write_handler(unsigned address, unsigned value)
{
	unsigned pix = IOREG(address);

	int x = pix % 160;
	int y = pix / 160;

	value &=0xff;
	unsigned int r,g,b;
	int i,j;
	Uint32 *pixels = (Uint32 *)screen->pixels;

	r = value>>5;
	g = (value>>2) &0x7;
	b = (value) &0x3;

	r<<=5;
	if(r&0x80) {
		//abort();
		//  r|=(1<<5)-1;
	}
	r<<=16;

	g<<=5;
	if(g&0x80) {
		//  g|=(1<<5)-1;
	}

	g<<=8;

	b<<=6;
	if(b&0x80) {
		// g|=(1<<6)-1;
	}

	unsigned pixel = r|g|b;

	for (i=x*5; i<(x+1)*5; i++) {
		for (j=y*5; j<(y+1)*5; j++) {

			pixels[( j * screen->w ) + i] = pixel;
		}
	}
}


static zpuino_device_t dev = {
	.name = "vga",
	.init = initialize_device,
	.read = vga_io_read_handler,
	.write = vga_io_write_handler,
	.post_init = NULL,
	.class = NULL
};

zpuino_device_t *get_device() {
	return &dev;
}
#else
zpuino_device_t *get_device() {
	return NULL;
}

#endif

