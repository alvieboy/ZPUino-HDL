#ifndef __ZPUINOINTERFACE_H__
#define __ZPUINOINTERFACE_H__

typedef unsigned int (*io_read_func_t)(unsigned int addr);
typedef void (*io_write_func_t)(unsigned int addr,unsigned int val);
typedef void (*tick_func_t)(unsigned delta);

typedef struct {
	const char *name;
	int (*init)(int argc,char**argv);
	io_read_func_t read;
	io_write_func_t write;
	int (*post_init)(void);
	void *class; // Class-specific definitions
} zpuino_device_t;

void zpuino_request_interrupt(int line);
void zpuino_request_tick( tick_func_t func );
void zpuino_io_set_read_func(unsigned int index, io_read_func_t f);
void zpuino_io_set_write_func(unsigned int index, io_write_func_t f);
void zpuino_interface_init();
zpuino_device_t *zpuino_get_device_by_name(const char *name);
void zpuino_io_post_init();
void byebye();
unsigned zpuino_get_tick_count();

char * makekeyvalue(char *arg);

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
