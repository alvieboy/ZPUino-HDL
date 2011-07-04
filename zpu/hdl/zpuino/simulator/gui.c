#include "gui.h"
#include "zpuinointerface.h"

static GtkWidget *topwindow;
static GtkWidget *mainvbox;
//static GtkWidget *menu;
static GtkWidget *note;
static GtkWidget *status;
static GtkWidget *toolbar;
static gint statusid;

extern void zpu_halt();
extern void zpu_reset();
extern void zpu_resume();

//static GtkWidget *icon_play,*icon_stop;

void gui_resume()
{
    fprintf(stderr,"resume\n");
	zpu_resume();
}

void gui_halt()
{
	fprintf(stderr,"halt\n");
	zpu_halt();
}

GtkWidget *start,*stop;

void gui_notify_zpu_halted()
{
	gui_set_status("ZPU halted");
}

void gui_notify_zpu_resumed()
{
	gui_set_status("ZPU running");
}

void gui_exit()
{
	byebye();
}

void gui_init()
{
	gtk_init(NULL,NULL);


	topwindow = gtk_window_new(GTK_WINDOW_TOPLEVEL);

	//gtk_widget_set_size_request(topwindow,800,600);
	gtk_window_set_title(GTK_WINDOW(topwindow),"ZPUino simulator");
	g_signal_connect(topwindow,"destroy",&gui_exit,NULL);
	mainvbox = gtk_vbox_new(FALSE,FALSE);

	gtk_container_add( GTK_CONTAINER(topwindow), mainvbox );

	toolbar = gtk_toolbar_new();
	gtk_box_pack_start( GTK_BOX(mainvbox), toolbar, 0, 0, 0);

	GtkWidget *icon_play = gtk_image_new_from_stock( GTK_STOCK_MEDIA_PLAY, GTK_ICON_SIZE_SMALL_TOOLBAR);
	GtkWidget *icon_stop = gtk_image_new_from_stock( GTK_STOCK_MEDIA_STOP, GTK_ICON_SIZE_SMALL_TOOLBAR);

	start = gtk_toolbar_insert_item(GTK_TOOLBAR(toolbar),
									NULL,
									"Resume ZPU",
									NULL,
									icon_play,
									&gui_resume,
									NULL
									,0);

	stop = gtk_toolbar_insert_item(GTK_TOOLBAR(toolbar),
								   NULL,
								   "Halt ZPU",
								   NULL,
								   icon_stop,
								   &gui_halt
								   ,
								   NULL
								   ,0);

	// TODO - add reset

	/*menu = gtk_menu_new();

	gtk_box_pack_start( GTK_BOX(mainvbox), menu, 0, 0, 0);
      */
	note = gtk_notebook_new();

	gtk_box_pack_start( GTK_BOX(mainvbox), note, 0, 0, 0);

	status = gtk_statusbar_new();

	gtk_box_pack_start( GTK_BOX(mainvbox), status, 0, 0, 0);

	statusid = gtk_statusbar_get_context_id(GTK_STATUSBAR(status),"MAIN");
}

void gui_post_init()
{
	gtk_widget_show_all(topwindow);
}

void gui_set_status(const char*text)
{
    gtk_statusbar_push(GTK_STATUSBAR(status),statusid,text);
}


int gui_append_new_tab(const char *name, GtkWidget *t)
{
	GtkWidget *label = gtk_label_new(name);
	gtk_notebook_append_page(GTK_NOTEBOOK(note),t,label);
	return 0;
}

GtkWidget *gui_get_top_window()
{
	return topwindow;
}
