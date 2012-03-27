.section ".boots", "a"

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
  /*
  	0x28
        0x2C
        0x30
        0x34
        0x38
  */