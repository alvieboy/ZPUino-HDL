#ifndef __GUI_H__
#define __GUI_H__

#include <gtk/gtk.h>

void gui_init();
void gui_post_init();

int gui_append_new_tab(const char *name, GtkWidget *t);

GtkWidget *gui_get_top_window();

void gui_set_status(const char*text);

void gui_notify_zpu_resumed();
void gui_notify_zpu_halted();

#endif
