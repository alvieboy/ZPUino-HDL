.text
	.globl _syscall_impl
_syscall_impl:
	loadsp 4
        im __syscall_table
        add
        load
        poppc
        
	breakpoint

.section ".rodata.syscall", "a"

.align 4
__syscall_table:	
        .long memcpy
        .long memset
