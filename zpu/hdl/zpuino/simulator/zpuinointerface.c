#include "zpuinointerface.h"
#include <sys/time.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <glib.h>

io_read_func_t io_read_table[1<<(IOSLOT_BITS)];
io_write_func_t io_write_table[1<<(IOSLOT_BITS)];
zpuino_device_t *io_devices[1<<(IOSLOT_BITS)];

GSList *tick_table = NULL;
unsigned zpuinoclock = 96000000;
unsigned int count=0; // ZPU ticks

struct timeval start;

unsigned zpuino_get_wall_tick_count()
{

	struct timeval diff,end;
	unsigned long long usecs;

	gettimeofday(&end,NULL);
	timersub(&end,&start,&diff);

	usecs = (unsigned long long)diff.tv_sec * 1000000ULL;
	usecs += diff.tv_usec;

	return usecs * (zpuinoclock/1000000);

}

unsigned zpuino_get_tick_count()
{
	return count;
}

void zpuino_clock_start()
{
	gettimeofday(&start,NULL);
}

void zpuino_clock_start_from_halted(const struct timeval*t)
{
	/* We need to move back clock: TODO */
	gettimeofday(&start,NULL);

}


void zpuino_io_set_device(int slot, zpuino_device_t*dev)
{
	io_devices[slot]=dev;
}

zpuino_device_t *zpuino_get_device_by_name(const char *name)
{
	int i;
	for (i=0; i<(1<<(IOSLOT_BITS)); i++) {
		if (io_devices[i]) {
			if (!(strcmp(io_devices[i]->name, name))) {
				return io_devices[i];
			}
		}
	}
	return NULL;
}


void zpuino_io_post_init()
{
	int i;
	for (i=0; i<(1<<(IOSLOT_BITS)); i++) {
		if (io_devices[i] && io_devices[i]->post_init) {
			io_devices[i]->post_init();
		}
	}
}

void zpuino_io_set_read_func(unsigned int index, io_read_func_t f)
{
	//printf("# READ Register idx %d address %08x\n", index, (index<<2) + IOBASE);
	io_read_table[index] = f;
}
void zpuino_io_set_write_func(unsigned int index, io_write_func_t f)
{
	//printf("# WRITE Register idx %d address %08x\n", index, (index<<2) + IOBASE);
	io_write_table[index] = f;
}


unsigned int zpuino_io_read_dummy(unsigned int address)
{
	fprintf(stderr,"ERROR: Invalid IO read, address 0x%08x (slot %d)\n",address,(address>>(MAXBITINCIO-IOSLOT_BITS))&0xf);
	//byebye();
	return 0;
}

void zpuino_io_write_dummy(unsigned int address,unsigned int val)
{
	printf("ERROR: Invalid IO write, address 0x%08x = 0x%08x (slot %d)\n",address,val, (address>>(MAXBITINCIO-IOSLOT_BITS))&0xf);
}

void sign(int s)
{
	double secs;
	struct timeval diff,end;

	gettimeofday(&end,NULL);
	timersub(&end,&start,&diff);
	secs = (double)diff.tv_sec;
	secs += (double)(diff.tv_usec)/1000000.0;

	printf("%u ticks in %f seconds\n", count,secs);
	printf("Frequency: %fMHz\n",(double)count/(secs*1000000.0));
	exit(-1);
}

void byebye()
{
	sign(0);
}

void zpuino_tick(unsigned v)
{
	GSList *i;
	for (i=tick_table; i; i=g_slist_next(i)) {
		((tick_func_t)(i->data))(v);
	}
	/*tick_func_t*tick=&tick_table[0];
	while (tick) {
		(*tick)(v);
		tick++;
		}
		*/
}

void zpuino_request_tick( tick_func_t func )
{
	tick_table = g_slist_append( tick_table, (void*)func);
}

void zpuino_interface_init()
{
	unsigned int i;

	for (i=0; i<(1<<(IOSLOT_BITS)); i++) {
		zpuino_io_set_read_func(i, &zpuino_io_read_dummy);
		zpuino_io_set_write_func(i, &zpuino_io_write_dummy);
		zpuino_io_set_device(i, NULL);
	}
}

char * makekeyvalue(char *arg)
{
	char *p = strchr(arg,'=');
	if (NULL==p)
		return p;
	*p++=0;
	return p;
}

int zpuino_device_parse_args(const zpuino_device_args_t *args, int argc, char **argv)
{
	int i;
	const zpuino_device_args_t *aptr;

	for (i=0;i<argc;i++) {
		char *k = argv[i];
		char *v = makekeyvalue(k);
		for (aptr=args;aptr->name;aptr++) {
			if (strcmp(k,aptr->name)==0) {
				switch (aptr->type) {
				case ARG_STRING:
					*((char**)aptr->target) = v;
					break;
				case ARG_INTEGER:
					*((int*)aptr->target) = atoi(v);
					break;

				default:
					break;
				}
				break;
			}
		}
	}
	return 0;
}

extern void zpu_halt();
extern void zpu_reset();
extern void zpu_resume();

void zpuino_softreset()
{
	zpu_halt();
	zpu_halt();
	zpu_reset();
	zpu_resume();
}

static GSList *devices=NULL;

void zpuino_register_device(const zpuino_device_t *dev)
{
	fprintf(stderr,"Registering device '%s'\n",dev->name);
	devices = g_slist_append(devices,(void*)dev);
}

zpuino_device_t *zpuino_find_device_by_name(const char*name)
{
	GSList*i;
	for (i=devices; i; i=g_slist_next(i)) {
		zpuino_device_t *d = i->data;
		if (strcmp(d->name,name)==0)
			return d;
	}
	return NULL;
}
