#include "register.h"

#define STACKTOP (BOARD_MEMORYSIZE - 0x8)

.text
.globl spi_copy
spi_copy:
       im STACKTOP
        popsp 
        im spi_copy_impl
        poppc
.globl start_sketch

start_sketch:
       im STACKTOP
        popsp
        im __sketch_start
        poppc

/* Interrupt handling */

.globl ___zpu_interrupt_vector
.type ___zpu_interrupt_vector, @function
___zpu_interrupt_vector:
	im _memreg
        load
        /* Get current interrupt */
        im SYSCTLBASE
        load
	im ivector
        load
        call
        storesp 0
        im _memreg
        store
        /* Re-enable interrupts */
        im 1
        nop
        im SYSCTLBASE
        store
        poppc
.size ___zpu_interrupt_vector, . - ___zpu_interrupt_vector

.section ".boots", ""

/* ATTENTION - this requires a very strict memory map. Do not change before
   thinking */
   
.balign 4,0	
	.globl ivector
        .globl bootloaderdata
ivector:
	.long 0 /* Will be set by bootloader */
bootloaderdata:
	.long 0 /* Will be set by bootloader */

.balign 4,0	        
        .globl __sketch_start
__sketch_start:
	nop

.section ".vectors"

	.org 0x0008
        .globl _memreg
_memreg:
        .org 0x0028
        .globl _bfunctions
_bfunctions:

.section ".rodata"
.global _bfunctionsconst
_bfunctionsconst:
	.long udivmodsi4
	.long memcpy
	.long memset
	.long strcmp
	.long loadsketch
