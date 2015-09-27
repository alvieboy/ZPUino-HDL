#include "register.h"
#include "zpuino.h"
extern void (*ivector)(void);

extern unsigned char __ram_start,__data_start,__data_end;

static void __copy_data(void)
{
	unsigned int *cptr;
	cptr = (unsigned int*)&__ram_start;
	unsigned int *dptr;
	dptr = (unsigned int*)&__data_start;

	do {
		*dptr = *cptr;
		cptr++,dptr++;
	} while (dptr<(unsigned int*)(&__data_end));
}

extern int main(int,char**);
extern void __sys_load();
extern void __tests();

#ifdef ZPUINO_HAS_ICACHE
#ifndef ZPUINO_NEED_SYSLOAD
#define ZPUINO_NEED_SYSLOAD
#endif
#endif

void _premain2(unsigned memtop)
{
   /* __tests(); */
#ifdef ZPUINO_NEED_SYSLOAD
	__sys_load();
#endif
	main(0,(char**)memtop);
}

