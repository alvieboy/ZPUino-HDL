#include "register.h"
#include "zpuino.h"

#define MEMTEST

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
#ifdef MEMTEST

#define MEMCHECK(a,v) \
    {                 \
    unsigned check;   \
    (*a) = v;         \
    check = ~(*a);     \
    if (check!=v) {   \
    putc('E');     \
    putc(' ');     \
    putc('A');     \
    putc('d');     \
    putc('d');     \
    putc('r');     \
    putc(' ');     \
    printhex((unsigned)a);     \
    putc(':'); \
    putc('R'); \
    putc('e'); \
    putc('a'); \
    putc('d'); \
    putc(' '); \
    printhex(v); \
    putc(' '); \
    putc('e'); \
    putc('x'); \
    putc('p'); \
    putc(' '); \
    printhex(check); \
    _endline(); \
    while (1) {}     \
    }                 \
    }

    // just mem test
    volatile unsigned *addr = (volatile unsigned *)0U;
    memtop>>=2; // Divide by 4.
    while (memtop--) {
        unsigned save = *addr;
        // Write pattern
        MEMCHECK(addr,0xaaaaaaaa);
        MEMCHECK(addr,0x55555555);
        MEMCHECK(addr,0xF0F0F0F0);
        MEMCHECK(addr,0x0F0F0F0F);
        MEMCHECK(addr,0xaaaa5555);
        MEMCHECK(addr,0x5555aaaa);
        MEMCHECK(addr,0x0000FFFF);
        MEMCHECK(addr,0xFFFF0000);
        addr++;
    }
    putc('M');
    putc('e');
    putc('m');
    putc(' ');
    putc('O');
    putc('K');
    _endline();

#else
   /* __tests(); */
#ifdef ZPUINO_NEED_SYSLOAD
	__sys_load();
#endif
        main(0,(char**)memtop);
#endif
}

