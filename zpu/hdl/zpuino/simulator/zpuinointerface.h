#ifndef __ZPUINOINTERFACE_H__
#define __ZPUINOINTERFACE_H__

#include "gui.h"

typedef unsigned int (*io_read_func_t)(unsigned int addr);
typedef void (*io_write_func_t)(unsigned int addr,unsigned int val);
typedef void (*tick_func_t)(unsigned delta);

extern unsigned zpuinoclock;

typedef struct {
	const char *name;
	int (*init)(int argc,char**argv);
	io_read_func_t read;
	io_write_func_t write;
	int (*post_init)(void);
	void *class; // Class-specific definitions
} zpuino_device_t;

enum zpuino_arg_type {
	ARG_STRING,
	ARG_INTEGER
};

#define ENDARGS { NULL, ARG_STRING, NULL }

typedef struct {
	const char *name;
	enum zpuino_arg_type type;
	void *target;
} zpuino_device_args_t;

void zpuino_request_interrupt(int line);
void zpuino_request_tick( tick_func_t func );
void zpuino_io_set_read_func(unsigned int index, io_read_func_t f);
void zpuino_io_set_write_func(unsigned int index, io_write_func_t f);
void zpuino_interface_init();
zpuino_device_t *zpuino_get_device_by_name(const char *name);
void zpuino_io_post_init();
void byebye();
unsigned zpuino_get_tick_count();
unsigned zpuino_get_wall_tick_count();
char * makekeyvalue(char *arg);

int zpuino_device_parse_args(const zpuino_device_args_t *args, int argc,char **argv);

void zpuino_tick(unsigned v);
void zpuino_clock_start_from_halted(const struct timeval*);
void zpuino_clock_start();
void zpuino_io_set_device(int slot, zpuino_device_t*dev);
void zpuino_softreset();
void zpuino_register_device(const zpuino_device_t*);
zpuino_device_t *zpuino_find_device_by_name(const char*name);

#define ZPUINOINIT __attribute__((constructor))

#define IOBASE 0x8000000
#define MAXBITINCIO 27
#define IOSLOT_BITS 4

#define IOREG(x) (((x) & ((1<<(MAXBITINCIO-1-IOSLOT_BITS))-1))>>2)

#define MAPREGR(index,method) \
	if (IOREG(address)==index) { return method(address); }

#define MAPREGW(index,method) \
	if (IOREG(address)==index) { method(address,value); return; }

#define ERRORREG(x) \
	fprintf(stderr, "%s: invalid register access %d\n",__FUNCTION__,IOREG(address)); \
	byebye();

#endif
