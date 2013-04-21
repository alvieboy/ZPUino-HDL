#include "register.h"
#include "zpuino.h"
extern void (*ivector)(void);

void ___zpu_interrupt_vector()
{
	__asm__("im _memreg\n"
			"load\n"
			"im _memreg+4\n"
			"load\n"
			"im _memreg+8\n"
			"load\n"
		   );
	ivector();
	__asm__("im _memreg+8\n"
			"store\n"
			"im _memreg+4\n"
			"store\n"
			"im _memreg+2\n"
			"store\n"
		   );
	// Re-enable interrupts
	INTRCTL=1;
}

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
void _premain()
{
   /* __tests(); */
#ifdef ZPUINO_HAS_ICACHE
	__sys_load();
#endif
	main(0,0);
}

void __attribute__((noreturn)) _opcode_swap()
{
	asm ("loadsp 0\n"
		 "im _opcode_swap_c\n"
		 "poppc\n");
	while (1);
}

