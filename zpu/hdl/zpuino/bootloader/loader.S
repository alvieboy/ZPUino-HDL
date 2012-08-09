#include "register.h"

.text

#undef PRELOADED 

.balign 16 /* Ensure we don't have a cache miss on this code */

.globl __flush
__flush:

        im         2                        ; Flush cache, enable SRAM
        nop
        im        IO_SLOT(4) + 16
        store
        nop
        nop
        nop
        poppc
        breakpoint

/* .balign 64 */
.globl __sys_load
__sys_load:


/*
.globl testcase
testcase:
	nop
        nop
        nop
        nop
	nop
        nop
        nop
        nop
	nop
        nop
        nop
        nop
	nop
        nop
        nop
        nop  
	nop
        nop
        nop
        nop
	nop
        nop
        nop
        nop
	nop
        nop
        nop
        nop
	nop
        nop
        nop
        nop  
	nop
        nop
        nop
        nop
	nop
        nop
        nop
        nop
	nop
        nop
        nop
        nop
	nop
        nop
        nop
        nop
	nop
        nop
        nop
        nop
	nop
        nop
        nop
        nop
	nop
        nop
        nop
        nop
	nop
        im 0x300
        call 
        nop
        nop
        */

#ifndef PRELOADED
        im        IO_SLOT(15)              // +4
        nop
        im        0                      // +8
        nop        
        im        4096                       // +12
.loop:
        loadsp        8               // +16
        addsp        8
        load        
        loadsp        8
        store
        /* Test loading it again  
        loadsp        4               // +16
        load        
        storesp 0
        End test */
        
        im        4
        addsp        8
        storesp 8
        loadsp        4
        loadsp        4
        eq        
        im -1
        add
        impcrel        .loop
        neqbranch
        pushsp        
        im        12
        add        
        popsp
#endif        
        im        __flush
        poppc

        
        