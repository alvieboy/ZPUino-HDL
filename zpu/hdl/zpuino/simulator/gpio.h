#ifndef __GPIO_H__
#define __GPIO_H__

typedef void (*gpio_notifier_callback_t)(unsigned,int,void*);

typedef struct {
	int (*add_pin_notify)(unsigned pin, gpio_notifier_callback_t callback, void *data);
	void (*set_pin)(unsigned pin, unsigned value);
} gpio_class_t;

#endif
