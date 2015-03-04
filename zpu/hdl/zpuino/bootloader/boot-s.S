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
        im SYSCTLBASE+8
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

.globl _premain
_premain:
    /* Try to detect memory size. Start at a reasonable offset (16KB).
     Assume memory size is 2^N
     */
    im 0
    loadsp 0
    store /* Store 0 to 0x0 */
    // Pattern is 0xa5a55a5a
    im 0xa5a55a5a
    // Start offset
    nop
    im 16384
    // Store the pattern
.loop:
    loadsp 4
    loadsp 4
    store
    // Load word at zero, compare with pattern
    loadsp 4
    im 0
    load
    eq
    impcrel .done
    neqbranch
    // Load address
    loadsp 0
    addsp 4 // Shift
    storesp 4

    im .loop
    poppc
.done:
    storesp 4
    im _premain2
    call

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

