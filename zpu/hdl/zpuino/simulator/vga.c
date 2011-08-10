#include "zpuinointerface.h"
#include "config.h"
#include "gpio.h"
#include <stdio.h>

#ifdef HAVE_SDL

#include <SDL.h>
#include <gtk/gtk.h>

#include <gdk/gdkkeysyms.h>

GdkGC* ignored_gc;
GdkImage* image = NULL;
GdkDrawable* drawable=NULL;
static SDL_Surface *screen;
GtkWidget *darea;

gpio_class_t *gpioclass = NULL;

void vga_sdl_flip(void*data)
{
	/* ~Flip/UpdateRect */
	if(drawable) {
		gdk_draw_image(drawable, ignored_gc, image, 0, 0,
					   0, 0, -1, -1);
	}
}

int vga_post_init()
{
	gtk_widget_realize(darea);

	zpuino_device_t *gpiodev = zpuino_get_device_by_name("gpio");

	if (NULL==gpiodev) {
		fprintf(stderr,"Cannot find device \"gpio\", cannot attach SPI select line");
		return -1;
	}
	gpioclass = gpiodev->class;

	return 0;
}

void vga_realize(GtkWidget*w,void*d)
{
	fprintf(stderr,"VGA initializing\n");

	drawable = darea->window;

	ignored_gc = gdk_gc_new(drawable);

	/*int width = -1, height = -1;
	gdk_drawable_get_size(drawable, &width, &height);
	*/


	GdkVisual* visual = gdk_drawable_get_visual(drawable);
	image = gdk_image_new(GDK_IMAGE_FASTEST, visual, 800, 600);
	screen = SDL_CreateRGBSurfaceFrom(image->mem, 800, 600, image->bits_per_pixel, image->bpl,
									  visual->red_mask, visual->green_mask, visual->blue_mask, 0);
}


gboolean vga_key_up(GtkWidget *widget, GdkEventKey *event, gpointer user_data)
{
	if(NULL==gpioclass)
		return FALSE;

	switch (event->keyval)
	{
	case GDK_KEY_Down:
	case GDK_KEY_KP_Down:
		gpioclass->set_pin(26,0);
		break;
	case GDK_KEY_KP_Up:
	case GDK_KEY_Up:
		gpioclass->set_pin(25,0);
		break;
	case GDK_KEY_KP_Left:
	case GDK_KEY_Left:
		gpioclass->set_pin(24,0);
		break;
	case GDK_KEY_KP_Right:
	case GDK_KEY_Right:
		gpioclass->set_pin(27,0);
		break;
	default:
		break;
	}
    return TRUE;
}

gboolean vga_key_down(GtkWidget *widget, GdkEventKey *event, gpointer     user_data)
{
	if(NULL==gpioclass)
		return FALSE;

	switch (event->keyval)
	{
	case GDK_KEY_Down:
	case GDK_KEY_KP_Down:
		gpioclass->set_pin(26,1);
		break;
	case GDK_KEY_KP_Up:
	case GDK_KEY_Up:
		gpioclass->set_pin(25,1);
		break;
	case GDK_KEY_KP_Left:
	case GDK_KEY_Left:
		gpioclass->set_pin(24,1);
		break;
	case GDK_KEY_KP_Right:
	case GDK_KEY_Right:
		gpioclass->set_pin(27,1);
		break;
	default:
		break;
	}
    return TRUE;
}

void vga_sdl_init_gtk()
{
	darea = gtk_drawing_area_new();

	gui_append_new_tab("VGA", darea);

	gtk_widget_set_size_request(darea,800,600);

	g_signal_connect( darea,"realize",(GCallback)&vga_realize,NULL);

	gtk_widget_set_sensitive(darea,TRUE);
	gtk_widget_set_can_focus(darea,TRUE);

	g_signal_connect(darea,"key-press-event", G_CALLBACK(&vga_key_down), NULL);
	g_signal_connect(darea,"key-release-event", G_CALLBACK(&vga_key_up), NULL);

}


void updater_thread()
{
	while (1) {
        /*
		 SDL_Flip(screen);
		 */
		//vga_sdl_flip();

		usleep(1000000/10);
	}
}

/*static pthread_t vgathread;
static pthread_attr_t vgathreadattr;
*/
static int initialize_device(int argc,char **argv)
{
    /*
	screen = SDL_SetVideoMode( 800, 600, 32, SDL_SWSURFACE );
	if (NULL==screen)
		return -1;
		*/
    vga_sdl_init_gtk();
	// Add updater thread
/*
	pthread_attr_init(&vgathreadattr);
	pthread_create(&vgathread,&vgathreadattr, updater_thread, NULL);
	*/
	gdk_threads_add_timeout(100,(GSourceFunc)&vga_sdl_flip,NULL);
	return 0;
}

unsigned vga_io_read_handler(unsigned address)
{
	unsigned pix = IOREG(address);
	int x = pix % 160;
	int y = pix / 160;

	int i,j;

	if (NULL==screen)
		return 0;

	Uint32 *pixels = (Uint32 *)screen->pixels;
	i=x*5;
	j=y*5;

	int p = pixels[( j * screen->w ) + i];

	// Convert
	int r,g,b;
	r = p>>21;
	g = (p>>13) &0x7;
	b = (p>>6) &0x3;

	return ( (r<<5) | (g<<2) |b);
}

void vga_io_write_handler(unsigned address, unsigned value)
{
	unsigned pix = IOREG(address);

	if (NULL==screen)
		return;

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
		 r|=(1<<5)-1;
	}
	r<<=16;

	g<<=5;
	if(g&0x80) {
		 g|=(1<<5)-1;
	}

	g<<=8;

	b<<=6;
	if(b&0x80) {
		 g|=(1<<6)-1;
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
	.post_init = vga_post_init,
	.class = NULL
};

static void ZPUINOINIT vga_init()
{
	zpuino_register_device(&dev);
}
#endif

