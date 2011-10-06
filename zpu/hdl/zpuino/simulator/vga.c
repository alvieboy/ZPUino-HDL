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

const int display_width = 640;
const int display_height = 480;

const int divide_width = 1;
const int divide_height = 1;

const int effective_width_pixels = 640;
const int effective_height_pixels = 480;

/* Color configuration */

#define BYTES_PER_PIXEL 2
#define COLOR_WEIGHT_R 4
#define COLOR_WEIGHT_G 4
#define COLOR_WEIGHT_B 4
#define COLOR_SHIFT_R (COLOR_WEIGHT_B+COLOR_WEIGHT_G)
#define COLOR_SHIFT_G (COLOR_WEIGHT_B)
#define COLOR_SHIFT_B 0


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
	image = gdk_image_new(GDK_IMAGE_FASTEST, visual, display_width, display_height);
	screen = SDL_CreateRGBSurfaceFrom(image->mem, display_width, display_height, image->bits_per_pixel, image->bpl,
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

	gtk_widget_set_size_request(darea,display_width,display_height);

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
	int x = pix % effective_width_pixels;
	int y = pix / effective_width_pixels;

	int i,j;

	if (NULL==screen)
		return 0;

	Uint32 *pixels = (Uint32 *)screen->pixels;

	i=x*divide_width;
	j=y*divide_height;

	int p = pixels[( j * screen->w ) + i];

	// Convert
	int r,g,b;
	r = p>>(24-COLOR_WEIGHT_R) & ((1<<COLOR_WEIGHT_R)-1);
	g = p>>(16-COLOR_WEIGHT_G) & ((1<<COLOR_WEIGHT_G)-1);
	b = p>>(8-COLOR_WEIGHT_B) & ((1<<COLOR_WEIGHT_B)-1);

	return ( (r<<COLOR_SHIFT_R) | (g<<COLOR_SHIFT_G) | (b<<COLOR_SHIFT_B));
}

void vga_io_write_handler(unsigned address, unsigned value)
{
	unsigned pix = IOREG(address);

	if (pix > (display_height*display_width))
		return;

	if (NULL==screen)
		return;

	int x = pix % effective_width_pixels;
	int y = pix / effective_width_pixels;

	if (y>effective_height_pixels)
		return;

   // printf("VGA: x %d y %d in 0x%08x, ",x,y,value);

	value &= ((1<<(COLOR_WEIGHT_B+COLOR_WEIGHT_R+COLOR_WEIGHT_G))-1);
 //   printf("Masked 0x%08x ",value);

	unsigned int r,g,b;
	int i,j;
	Uint32 *pixels = (Uint32 *)screen->pixels;

	r = ( value>>8 ) & ((1<<COLOR_WEIGHT_R)-1);
	g = ( value>>4 ) & ((1<<COLOR_WEIGHT_G)-1);
	b = ( value>>0 ) & ((1<<COLOR_WEIGHT_B)-1);
//	printf("R=%x,G=%x,B=%x, remap ",r,g,b);

	r<<=(8-COLOR_WEIGHT_R);
	if(r&0x80) {
		 r|=(1<<(8-COLOR_WEIGHT_R))-1;
	}
	r<<=16;

	g<<=(8-COLOR_WEIGHT_G);
	if(g&0x80) {
		 g|=(1<<(8-COLOR_WEIGHT_G))-1;
	}

	g<<=8;

	b<<=(8-COLOR_WEIGHT_B);
	if(b&0x80) {
		 b|=(1<<(8-COLOR_WEIGHT_B))-1;
	}

   // printf("R=%x,G=%x,B=%x\n",r,g,b);
	unsigned pixel = r|g|b;

	for (i=x*divide_width; i<(x+1)*divide_width; i++) {
		for (j=y*divide_height; j<(y+1)*divide_height; j++) {
			//printf("Off %d\n",( j * screen->w ) + i);
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

