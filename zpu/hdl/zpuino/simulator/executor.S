
/*
        Registers EAX, ECX, and EDX are available for use in the function.
        C calling standard
*/

#define TRACE
        
        .globl execute

#define STACKMASK 0x1FFF
#define MEMMASK 0x3FFFFF
#define STACKPAGEMASK (MEMMASK ^ STACKMASK)

#define MAXADDRBITINCIO $27

.do_tick:
        push %edx
        // stage delay
        pushl _tickgranularity
        call tick
        add $4, %esp
        pop %edx
        movl _tickgranularity, %eax
        movl %eax, _currenttickgranularity
        jmp .do_tick_return
        
execute:
        pusha /* Save everything */
        std
        movl _usp, %esi
        movl _upc, %edi     /* edi: PC */
        xorl %edx,%edx

        movl _tickgranularity, %eax
        movl %eax, _currenttickgranularity
        
        // Preload stack top
        push %esi
        and $STACKMASK, %esi
        movl _stack(%esi), %ebx
        pop %esi
        bswap %ebx
.loop:
        
        /* Check if we're to halt */
        movl request_halt, %eax
        test %eax, %eax
        jne .do_halt

.cannot_halt:
        // Check granularity
        movl _currenttickgranularity, %eax
        decl _currenttickgranularity
        test %eax, %eax
        jz .do_tick
.do_tick_return:
       /* Check interrupt */
        mov do_interrupt, %eax 
        test %eax, %eax
        jne .jump_to_interrupt 
.fetch:
       /* Trace stuff. Remove for performance */
#ifdef TRACE        
        pusha
        push %ebx
        push %esi
        push %edi
        call trace
        add $12, %esp
        popa
#endif        

        movzbl _memory(,%edi), %eax /* Load opcode */
        addl %edx, %eax /* For idim */                
        movl dispatchtable(,%eax,4), %ecx /* ecx: routine to call */
        movl %eax, %edx  /* Save opcode */
        jmp *%ecx
.opcode_return_and_load:

.opcode_return:
        andl $128, %edx
        shl $1, %edx
        incl count
        jmp .loop
.do_halt:
        /* Only go back to "C" if we're not processing IDIM */
        test %edx, %edx
        jnz .cannot_halt
        /* Go back to "C" */
        bswap %ebx

        push %esi
        and $STACKMASK, %esi
        movl %ebx, _stack(%esi)
	pop %esi 
        
        movl %esi, _usp
        movl %edi, _upc
        
        popa
        movl $0, %eax
        ret
        
.jump_to_interrupt:
        // Skip interrupt if IDIM flag is set
        test %edx, %edx
        jne .fetch
        // Write back
        movl %ebx, %eax
        bswap %eax
        push %esi
        and $STACKMASK, %esi
        movl %eax, _stack(%esi)
        pop %esi
        subl $4,%esi
        movl %edi, %ebx
        movl $0x20, %edi
        movl $0, do_interrupt
        jmp .fetch

.align 16
zpu_nop:
        incl %edi
        jmp .opcode_return
zpu_fmul16:
	push %esi
        and $STACKMASK, %esi
        movl _stack+4(%esi), %eax
        pop %esi
        bswap %eax
        addl $4, %esi
        incl %edi
        push %edx
        imull %ebx
        shrd   $0x10,%edx,%eax
        movl %eax, %ebx
        pop %edx
        jmp .opcode_return

zpu_ibreak:
        bswap %ebx
        push %esi
        and $STACKMASK, %esi
        movl %ebx, _stack(%esi)
        pop  %esi
        movl %esi, _usp
        movl %edi, _upc

        popa
        movl $1, %eax
        ret /* Will go back to C */

zpu_pushsp:
        // Write back
        movl %ebx,%eax
        bswap %eax
        push %esi
        and $STACKMASK, %esi
        movl %eax, _stack(%esi)
        pop %esi
        movl %esi, %ebx
        orl $0x80000000, %ebx
        subl $4,%esi
        incl %edi
        jmp .opcode_return

zpu_poppc:
        movl %ebx, %edi
        addl $4, %esi
        push %esi
        and $STACKMASK, %esi
        movl _stack(%esi), %ebx
        pop %esi
        bswap %ebx
        jmp .opcode_return

.align 16
zpu_add:
	push %esi
        and $STACKMASK, %esi
        movl _stack+4(%esi), %eax
        pop %esi
        bswap %eax
        addl $4, %esi
        incl %edi
        addl %eax, %ebx
        jmp .opcode_return

zpu_or:
	push %esi
        and $STACKMASK, %esi
        movl _stack+4(%esi), %eax
        pop %esi
        bswap %eax
        orl %eax, %ebx
        addl $4, %esi
        incl %edi
        jmp .opcode_return

zpu_and:
	push %esi
        and $STACKMASK, %esi
        movl _stack+4(%esi), %eax
        pop %esi
        bswap %eax
        addl $4, %esi
        incl %edi
        andl %eax, %ebx
        jmp .opcode_return
.align 16
zpu_not:
        not %ebx
        incl %edi
        jmp .opcode_return
        
        
        .globl BitReverseTable256
zpu_flip:
        mov    %ebx,%eax
        shr    %ebx
        and    $0x55555555,%eax
        and    $0x55555555,%ebx
        add    %eax,%eax
        or     %ebx,%eax
        mov    %eax,%ebx
        and    $0x33333333,%eax
        shr    $0x2,%ebx
        shl    $0x2,%eax
        and    $0x33333333,%ebx
        or     %ebx,%eax
        mov    %eax,%ebx
        and    $0xf0f0f0f,%eax
        shr    $0x4,%ebx
        shl    $0x4,%eax
        and    $0xf0f0f0f,%ebx
        or     %ebx,%eax
        mov    %eax,%ebx
        and    $0xff00ff,%eax
        shr    $0x8,%ebx
        shl    $0x8,%eax
        and    $0xff00ff,%ebx
        or     %ebx,%eax
        ror    $0x10,%eax
        movl   %eax, %ebx
        incl   %edi
        jmp .opcode_return

zpu_storeb:
        // Address in %ebx
        addl $4, %esi
        push %esi
        and $STACKMASK, %esi
        movl _stack(%esi), %ecx //value
        pop %esi
        bswap %ecx
        addl $4, %esi
        bt MAXADDRBITINCIO, %ebx
        jc abort
        bt $31, %ebx
        jnc storeb_to_memory

        and $STACKMASK, %ebx
        movb %cl, _stack(%ebx)
        
        push %esi
        and $STACKMASK, %esi
	movl _stack(%esi), %ebx // Reload stack top
        pop %esi
        bswap %ebx
        incl %edi
        jmp .opcode_return

storeb_to_memory:
        movb %cl, _memory(%ebx)
        push %esi
        and $STACKMASK, %esi
        movl _stack(%esi), %ebx // Reload stack top
        pop %esi
        bswap %ebx
        incl %edi
        jmp .opcode_return



zpu_store:
        // Address in %ebx
        addl $4, %esi
        push %esi
        and $STACKMASK, %esi
        movl _stack(%esi), %ecx //value
        pop %esi
        addl $4, %esi
        bt MAXADDRBITINCIO, %ebx
        jc store_external
        bt $31, %ebx
        jnc store_to_memory

        and $STACKMASK, %ebx
        movl %ecx, _stack(%ebx)
        
        push %esi
        and $STACKMASK, %esi
        movl _stack(%esi), %ebx // Reload stack top
        pop %esi
        bswap %ebx
        incl %edi
        jmp .opcode_return

store_to_memory:
        movl %ecx, _memory(%ebx)
        push %esi
        and $STACKMASK, %esi
        movl _stack(%esi), %ebx // Reload stack top
        pop %esi
        bswap %ebx
        incl %edi
        jmp .opcode_return

store_external:
        bswap %ecx
        //mov io_write_table-32768(%ebx), %eax

        movl %ebx, %eax
        // Shift/And to get proper IO 
        shrl $21, %eax
        andl $0x3c, %eax
        mov io_write_table(%eax), %eax

        movl %edi, _upc
        push %edx
        push %ecx
        push %ebx
        call *%eax
        add $8, %esp
        pop %edx
        
        push %esi
        and $STACKMASK, %esi
        movl _stack(%esi), %ebx // Reload stack top
        pop %esi
        bswap %ebx
        incl %edi
        jmp .opcode_return

zpu_loadb:
        bt MAXADDRBITINCIO, %ebx
        jc abort
        bt $31, %ebx
        jc loadb_stack
        movb _memory(%ebx), %bl
        and $0xff, %ebx
        bswap %ebx
        incl %edi
        jmp .opcode_return

loadb_stack:
        and $STACKMASK, %ebx
        movb _stack(%ebx), %bl
        and $0xff, %ebx
        bswap %ebx
        incl %edi
        jmp .opcode_return


zpu_load:
        bt MAXADDRBITINCIO, %ebx
        jc load_external
        bt $31, %ebx
        jc load_stack

        movl _memory(%ebx), %ebx
        bswap %ebx
        incl %edi
        jmp .opcode_return

load_stack:
        and $STACKMASK, %ebx
        movl _stack(%ebx), %ebx
        bswap %ebx
        incl %edi
        jmp .opcode_return

load_external:
        movl %ebx, %eax
        // Shift/And to get proper IO 
        shrl $21, %eax
        andl $0x3c, %eax
        mov io_read_table(%eax), %eax
        push %edx
        push %ebx
        call *%eax
        add $4, %esp
        pop %edx
        movl %eax, %ebx
        incl %edi
        jmp .opcode_return      
        
.macro addspX off
	push %esi
        and $STACKMASK, %esi
        movl _stack+\off(%esi), %eax   // Load
        pop %esi
        bswap %eax
        addl %eax, %ebx
        incl %edi
        jmp .opcode_return
.endm
        
zpu_addsp0:
        // Special case ????
        addl %ebx, %ebx
        incl %edi
        jmp .opcode_return
zpu_addsp1:
        addspX 4
zpu_addsp2:
        addspX 8
zpu_addsp3:
        addspX 12
zpu_addsp4:
        addspX 16
zpu_addsp5:
        addspX 20
zpu_addsp6:
        addspX 24
zpu_addsp7:
        addspX 28
zpu_addsp8:
        addspX 32
zpu_addsp9:
        addspX 36
zpu_addsp10:
        addspX 40
zpu_addsp11:
        addspX 44
zpu_addsp12:
        addspX 48
zpu_addsp13:
        addspX 52
zpu_addsp14:
        addspX 56
zpu_addsp15:
        addspX 60

.macro emulateX off
        // Write back
        bswap %ebx
        push %esi
        and $STACKMASK, %esi
        movl %ebx, _stack(%esi)
        pop %esi
        subl $4, %esi
        incl %edi
        movl %edi, %ebx
        movl $\off*32, %edi
        jmp .opcode_return
.endm

zpu_emulate0:            // 32 Reset
        emulateX 0
zpu_emulate1:            // 33 Interrupt
        emulateX 1
zpu_emulate2:            // 34 LoadH
        emulateX 2
zpu_emulate3:            // 35 StoreH
        emulateX 3
zpu_emulate4:            // 36 Lessthan
        emulateX 4             
zpu_emulate5:            // 37 Lessthanorequal
        emulateX 5
zpu_emulate6:            // 38 Ulessthan
        // emulateX 6
        push %esi
        and $STACKMASK, %esi
        movl _stack+4(%esi), %eax
        pop %esi
        addl $4, %esi
        bswap %eax
        incl %edi
        cmpl %eax, %ebx
        movl $0, %ebx
        jae .opcode_return
        incl %ebx
        jmp .opcode_return

zpu_emulate7:            // 39 Ulessthanorequal
        emulateX 7
zpu_emulate8:            // 40 Swap (unused)
        emulateX 8
zpu_emulate9:            // 41 Mult
        emulateX 9
zpu_emulate10:           // 42 Lshiftright
        emulateX 10
zpu_emulate11:           // 43 Ashiftleft
        emulateX 11
zpu_emulate12:           // 44 Ashiftright
        emulateX 12
zpu_emulate13:           // 45 Call
        // emulateX 13
        /*
         push %ebx
        mov %edi, %eax
        incl %eax
        bswap %eax
        push %esi
        and $STACKMASK, %esi
        movl %eax, _stack(%esi)
        pop %esi
        
        incl %edi
        movl %edi, %ebx  // Return address in stack
        pop %eax
        movl %eax, %edi
        */
        xchg %edi, %ebx
        incl %ebx
        jmp .opcode_return

zpu_emulate14:           // 46 Eq
        //emulateX 14
        push %esi
        and $STACKMASK, %esi
        movl _stack+4(%esi), %eax
        pop %esi
        addl $4, %esi
        bswap %eax
        incl %edi
        cmpl %eax, %ebx
        movl $0, %ebx
        jne .opcode_return
        incl %ebx
        jmp .opcode_return

zpu_emulate15:           // 47 Neq
        emulateX 15
zpu_emulate16:           // 48 Neg
        emulateX 16
zpu_emulate17:           // 49 Sub
        emulateX 17
zpu_emulate18:           // 50 Xor
        emulateX 18
zpu_emulate19:           // 51 Loadb
        emulateX 19
zpu_emulate20:           // 52 Storeb
        emulateX 20
zpu_emulate21:           // 53 Div
        emulateX 21
zpu_emulate22:           // 54 Mod
        emulateX 22
zpu_emulate23:           // 55 Eqbranch
        emulateX 23
zpu_emulate24:           // 56 Neqbranch
        // emulateX 24
        // PC is in %ebx
        
        push %esi
        and $STACKMASK, %esi
        movl _stack+4(%esi), %eax
        pop %esi
        addl $8, %esi
        test %eax, %eax
        jz .no_jump
        add %ebx, %edi
        push %esi
        and $STACKMASK, %esi
        movl _stack(%esi), %ebx
        pop %esi
        bswap %ebx
        jmp .opcode_return
.no_jump:
        incl %edi              
        push %esi
        and $STACKMASK, %esi
        movl _stack(%esi), %ebx
        pop %esi
        bswap %ebx

        jmp .opcode_return

zpu_emulate25:           // 57 Poppcrel
        emulateX 25
zpu_emulate26:           // 58 Config
        emulateX 26
zpu_emulate27:           // 59 Pushpc
        emulateX 27
zpu_emulate28:           // 60 Syscall
        emulateX 28
zpu_emulate29:           // 61 Pushspadd
        emulateX 29
zpu_emulate30:           // 62 Halfmult
        emulateX 30
zpu_emulate31:           // 63 Callpcrel
        emulateX 31
        
zpu_popsp:
        // Write back
        movl %ebx, %eax
        bswap %eax
        push %esi
        andl $STACKMASK, %esi

        movl %eax, _stack(%esi)
        pop %esi
        // Check if we're on a different page
        push %ebx
        movl %esi, %eax
    	andl  $STACKPAGEMASK, %ebx
        andl  $STACKPAGEMASK, %esi
        cmp  %esi, %ebx
        
        jz	.stack_same_page
        
.globl not_same_page
not_same_page:
        // Ok, we have to writeback current stack
        // Original address is in %eax
        push 	%esi
        push 	%edi
        andl	$STACKPAGEMASK, %eax
        addl	$_memory, %eax
        movl	%eax, %edi
        
        movl  	$_stack, %esi
        cld
        movl  	$2040, %ecx
        rep 	movsd
        // Ok, now load from memory, from %ebx 
        movl  	$2040, %ecx
        movl 	%ebx, %esi
        andl	$STACKPAGEMASK, %esi
        addl	$_memory, %esi
        movl  	$_stack, %edi
        rep	movsd
        pop	%edi
        pop	%esi
	
.stack_same_page:

        pop %ebx
        and $MEMMASK, %ebx
	
        movl %ebx, %esi    // EBX ->> stack pointer

	push %esi
        and $STACKMASK, %esi
        movl _stack(%esi), %ebx  // Load new SP value to TOS
        pop %esi
        
        bswap %ebx
        incl %edi
        jmp .opcode_return
        
.macro storespX off
        bswap %ebx
        push %esi
        and $STACKMASK, %esi

        movl %ebx, _stack+\off*4(%esi)
        pop %esi
        addl $4, %esi
        push %esi
        and $STACKMASK, %esi
        movl _stack(%esi), %ebx
        pop %esi
        bswap %ebx
        incl %edi
        jmp .opcode_return
.endm

zpu_storesp0:
        storespX 0
zpu_storesp1:
        storespX 1
zpu_storesp2:
        storespX 2
zpu_storesp3:
        storespX 3
zpu_storesp4:
        storespX 4
zpu_storesp5:
        storespX 5
zpu_storesp6:
        storespX 6
zpu_storesp7:
        storespX 7
zpu_storesp8:
        storespX 8
zpu_storesp9:
        storespX 9
zpu_storesp10:
        storespX 10
zpu_storesp11:
        storespX 11
zpu_storesp12:
        storespX 12
zpu_storesp13:
        storespX 13
zpu_storesp14:
        storespX 14
zpu_storesp15:
        storespX 15
zpu_storesp16:
        storespX 16
zpu_storesp17:
        storespX 17
zpu_storesp18:
        storespX 18
zpu_storesp19:
        storespX 19
zpu_storesp20:
        storespX 20
zpu_storesp21:
        storespX 21
zpu_storesp22:
        storespX 22
zpu_storesp23:
        storespX 23
zpu_storesp24:
        storespX 24
zpu_storesp25:
        storespX 25
zpu_storesp26:
        storespX 26
zpu_storesp27:
        storespX 27
zpu_storesp28:
        storespX 28
zpu_storesp29:
        storespX 29
zpu_storesp30:
        storespX 30
zpu_storesp31:
        storespX 31


.macro loadspX off
        // Write back
        bswap %ebx
        
        push %esi
        and $STACKMASK, %esi
        movl %ebx, _stack(%esi)
        movl _stack+(\off*4)(%esi), %ebx
        pop %esi
        bswap %ebx
        subl $4, %esi
        incl %edi
        jmp .opcode_return
.endm

zpu_loadsp0:
        loadspX 0
zpu_loadsp1:
        loadspX 1
zpu_loadsp2:
        loadspX 2
zpu_loadsp3:
        loadspX 3
zpu_loadsp4:
        loadspX 4
zpu_loadsp5:
        loadspX 5
zpu_loadsp6:
        loadspX 6
zpu_loadsp7:
        loadspX 7
zpu_loadsp8:
        loadspX 8
zpu_loadsp9:
        loadspX 9
zpu_loadsp10:
        loadspX 10
zpu_loadsp11:
        loadspX 11
zpu_loadsp12:
        loadspX 12
zpu_loadsp13:
        loadspX 13
zpu_loadsp14:
        loadspX 14
zpu_loadsp15:
        loadspX 15
zpu_loadsp16:
        loadspX 16
zpu_loadsp17:
        loadspX 17
zpu_loadsp18:
        loadspX 18
zpu_loadsp19:
        loadspX 19
zpu_loadsp20:
        loadspX 20
zpu_loadsp21:
        loadspX 21
zpu_loadsp22:
        loadspX 22
zpu_loadsp23:
        loadspX 23
zpu_loadsp24:
        loadspX 24
zpu_loadsp25:
        loadspX 25
zpu_loadsp26:
        loadspX 26
zpu_loadsp27:
        loadspX 27
zpu_loadsp28:
        loadspX 28
zpu_loadsp29:
        loadspX 29
zpu_loadsp30:
        loadspX 30
zpu_loadsp31:
        loadspX 31

.macro firstimX val
        // Write back
        bswap %ebx
        push %esi
        and $STACKMASK, %esi

        movl %ebx, _stack(%esi)
	pop %esi
        subl $4, %esi
        movl $\val, %ebx
        incl %edi
        jmp .opcode_return
.endm

zpu_first_im0:
        firstimX 0
zpu_first_im1:
        firstimX 1
zpu_first_im2:
        firstimX 2
zpu_first_im3:
        firstimX 3
zpu_first_im4:
        firstimX 4
zpu_first_im5:
        firstimX 5
zpu_first_im6:
        firstimX 6
zpu_first_im7:
        firstimX 7
zpu_first_im8:
        firstimX 8
zpu_first_im9:
        firstimX 9
zpu_first_im10:
        firstimX 10
zpu_first_im11:
        firstimX 11
zpu_first_im12:
        firstimX 12
zpu_first_im13:
        firstimX 13
zpu_first_im14:
        firstimX 14
zpu_first_im15:
        firstimX 15
zpu_first_im16:
        firstimX 16
zpu_first_im17:
        firstimX 17
zpu_first_im18:
        firstimX 18
zpu_first_im19:
        firstimX 19
zpu_first_im20:
        firstimX 20
zpu_first_im21:
        firstimX 21
zpu_first_im22:
        firstimX 22
zpu_first_im23:
        firstimX 23
zpu_first_im24:
        firstimX 24
zpu_first_im25:
        firstimX 25
zpu_first_im26:
        firstimX 26
zpu_first_im27:
        firstimX 27
zpu_first_im28:
        firstimX 28
zpu_first_im29:
        firstimX 29
zpu_first_im30:
        firstimX 30
zpu_first_im31:
        firstimX 31
zpu_first_im32:
        firstimX 32
zpu_first_im33:
        firstimX 33
zpu_first_im34:
        firstimX 34
zpu_first_im35:
        firstimX 35
zpu_first_im36:
        firstimX 36
zpu_first_im37:
        firstimX 37
zpu_first_im38:
        firstimX 38
zpu_first_im39:
        firstimX 39
zpu_first_im40:
        firstimX 40
zpu_first_im41:
        firstimX 41
zpu_first_im42:
        firstimX 42
zpu_first_im43:
        firstimX 43
zpu_first_im44:
        firstimX 44
zpu_first_im45:
        firstimX 45
zpu_first_im46:
        firstimX 46
zpu_first_im47:
        firstimX 47
zpu_first_im48:
        firstimX 48
zpu_first_im49:
        firstimX 49
zpu_first_im50:
        firstimX 50
zpu_first_im51:
        firstimX 51
zpu_first_im52:
        firstimX 52
zpu_first_im53:
        firstimX 53
zpu_first_im54:
        firstimX 54
zpu_first_im55:
        firstimX 55
zpu_first_im56:
        firstimX 56
zpu_first_im57:
        firstimX 57
zpu_first_im58:
        firstimX 58
zpu_first_im59:
        firstimX 59
zpu_first_im60:
        firstimX 60
zpu_first_im61:
        firstimX 61
zpu_first_im62:
        firstimX 62
zpu_first_im63:
        firstimX 63
zpu_first_im64:
        firstimX -64
zpu_first_im65:
        firstimX -63
zpu_first_im66:
        firstimX -62
zpu_first_im67:
        firstimX -61
zpu_first_im68:
        firstimX -60
zpu_first_im69:
        firstimX -59
zpu_first_im70:
        firstimX -58
zpu_first_im71:
        firstimX -57
zpu_first_im72:
        firstimX -56
zpu_first_im73:
        firstimX -55
zpu_first_im74:
        firstimX -54
zpu_first_im75:
        firstimX -53
zpu_first_im76:
        firstimX -52
zpu_first_im77:
        firstimX -51
zpu_first_im78:
        firstimX -50
zpu_first_im79:
        firstimX -49
zpu_first_im80:
        firstimX -48
zpu_first_im81:
        firstimX -47
zpu_first_im82:
        firstimX -46
zpu_first_im83:
        firstimX -45
zpu_first_im84:
        firstimX -44
zpu_first_im85:
        firstimX -43
zpu_first_im86:
        firstimX -42
zpu_first_im87:
        firstimX -41
zpu_first_im88:
        firstimX -40
zpu_first_im89:
        firstimX -39
zpu_first_im90:
        firstimX -38
zpu_first_im91:
        firstimX -37
zpu_first_im92:
        firstimX -36
zpu_first_im93:
        firstimX -35
zpu_first_im94:
        firstimX -34
zpu_first_im95:
        firstimX -33
zpu_first_im96:
        firstimX -32
zpu_first_im97:
        firstimX -31
zpu_first_im98:
        firstimX -30
zpu_first_im99:
        firstimX -29
zpu_first_im100:
        firstimX -28
zpu_first_im101:
        firstimX -27
zpu_first_im102:
        firstimX -26
zpu_first_im103:
        firstimX -25
zpu_first_im104:
        firstimX -24
zpu_first_im105:
        firstimX -23
zpu_first_im106:
        firstimX -22
zpu_first_im107:
        firstimX -21
zpu_first_im108:
        firstimX -20
zpu_first_im109:
        firstimX -19
zpu_first_im110:
        firstimX -18
zpu_first_im111:
        firstimX -17
zpu_first_im112:
        firstimX -16
zpu_first_im113:
        firstimX -15
zpu_first_im114:
        firstimX -14
zpu_first_im115:
        firstimX -13
zpu_first_im116:
        firstimX -12
zpu_first_im117:
        firstimX -11
zpu_first_im118:
        firstimX -10
zpu_first_im119:
        firstimX -9
zpu_first_im120:
        firstimX -8
zpu_first_im121:
        firstimX -7
zpu_first_im122:
        firstimX -6
zpu_first_im123:
        firstimX -5
zpu_first_im124:
        firstimX -4
zpu_first_im125:
        firstimX -3
zpu_first_im126:
        firstimX -2
zpu_first_im127:
        firstimX -1

.macro nextimX val
        shl $7, %ebx
        or $\val, %ebx
        incl %edi
        jmp .opcode_return
.endm

zpu_next_im0:
        nextimX 0
zpu_next_im1:
        nextimX 1
zpu_next_im2:
        nextimX 2
zpu_next_im3:
        nextimX 3
zpu_next_im4:
        nextimX 4
zpu_next_im5:
        nextimX 5
zpu_next_im6:
        nextimX 6
zpu_next_im7:
        nextimX 7
zpu_next_im8:
        nextimX 8
zpu_next_im9:
        nextimX 9
zpu_next_im10:
        nextimX 10
zpu_next_im11:
        nextimX 11
zpu_next_im12:
        nextimX 12
zpu_next_im13:
        nextimX 13
zpu_next_im14:
        nextimX 14
zpu_next_im15:
        nextimX 15
zpu_next_im16:
        nextimX 16
zpu_next_im17:
        nextimX 17
zpu_next_im18:
        nextimX 18
zpu_next_im19:
        nextimX 19
zpu_next_im20:
        nextimX 20
zpu_next_im21:
        nextimX 21
zpu_next_im22:
        nextimX 22
zpu_next_im23:
        nextimX 23
zpu_next_im24:
        nextimX 24
zpu_next_im25:
        nextimX 25
zpu_next_im26:
        nextimX 26
zpu_next_im27:
        nextimX 27
zpu_next_im28:
        nextimX 28
zpu_next_im29:
        nextimX 29
zpu_next_im30:
        nextimX 30
zpu_next_im31:
        nextimX 31
zpu_next_im32:
        nextimX 32
zpu_next_im33:
        nextimX 33
zpu_next_im34:
        nextimX 34
zpu_next_im35:
        nextimX 35
zpu_next_im36:
        nextimX 36
zpu_next_im37:
        nextimX 37
zpu_next_im38:
        nextimX 38
zpu_next_im39:
        nextimX 39
zpu_next_im40:
        nextimX 40
zpu_next_im41:
        nextimX 41
zpu_next_im42:
        nextimX 42
zpu_next_im43:
        nextimX 43
zpu_next_im44:
        nextimX 44
zpu_next_im45:
        nextimX 45
zpu_next_im46:
        nextimX 46
zpu_next_im47:
        nextimX 47
zpu_next_im48:
        nextimX 48
zpu_next_im49:
        nextimX 49
zpu_next_im50:
        nextimX 50
zpu_next_im51:
        nextimX 51
zpu_next_im52:
        nextimX 52
zpu_next_im53:
        nextimX 53
zpu_next_im54:
        nextimX 54
zpu_next_im55:
        nextimX 55
zpu_next_im56:
        nextimX 56
zpu_next_im57:
        nextimX 57
zpu_next_im58:
        nextimX 58
zpu_next_im59:
        nextimX 59
zpu_next_im60:
        nextimX 60
zpu_next_im61:
        nextimX 61
zpu_next_im62:
        nextimX 62
zpu_next_im63:
        nextimX 63
zpu_next_im64:
        nextimX 64
zpu_next_im65:
        nextimX 65
zpu_next_im66:
        nextimX 66
zpu_next_im67:
        nextimX 67
zpu_next_im68:
        nextimX 68
zpu_next_im69:
        nextimX 69
zpu_next_im70:
        nextimX 70
zpu_next_im71:
        nextimX 71
zpu_next_im72:
        nextimX 72
zpu_next_im73:
        nextimX 73
zpu_next_im74:
        nextimX 74
zpu_next_im75:
        nextimX 75
zpu_next_im76:
        nextimX 76
zpu_next_im77:
        nextimX 77
zpu_next_im78:
        nextimX 78
zpu_next_im79:
        nextimX 79
zpu_next_im80:
        nextimX 80
zpu_next_im81:
        nextimX 81
zpu_next_im82:
        nextimX 82
zpu_next_im83:
        nextimX 83
zpu_next_im84:
        nextimX 84
zpu_next_im85:
        nextimX 85
zpu_next_im86:
        nextimX 86
zpu_next_im87:
        nextimX 87
zpu_next_im88:
        nextimX 88
zpu_next_im89:
        nextimX 89
zpu_next_im90:
        nextimX 90
zpu_next_im91:
        nextimX 91
zpu_next_im92:
        nextimX 92
zpu_next_im93:
        nextimX 93
zpu_next_im94:
        nextimX 94
zpu_next_im95:
        nextimX 95
zpu_next_im96:
        nextimX 96
zpu_next_im97:
        nextimX 97
zpu_next_im98:
        nextimX 98
zpu_next_im99:
        nextimX 99
zpu_next_im100:
        nextimX 100
zpu_next_im101:
        nextimX 101
zpu_next_im102:
        nextimX 102
zpu_next_im103:
        nextimX 103
zpu_next_im104:
        nextimX 104
zpu_next_im105:
        nextimX 105
zpu_next_im106:
        nextimX 106
zpu_next_im107:
        nextimX 107
zpu_next_im108:
        nextimX 108
zpu_next_im109:
        nextimX 109
zpu_next_im110:
        nextimX 110
zpu_next_im111:
        nextimX 111
zpu_next_im112:
        nextimX 112
zpu_next_im113:
        nextimX 113
zpu_next_im114:
        nextimX 114
zpu_next_im115:
        nextimX 115
zpu_next_im116:
        nextimX 116
zpu_next_im117:
        nextimX 117
zpu_next_im118:
        nextimX 118
zpu_next_im119:
        nextimX 119
zpu_next_im120:
        nextimX 120
zpu_next_im121:
        nextimX 121
zpu_next_im122:
        nextimX 122
zpu_next_im123:
        nextimX 123
zpu_next_im124:
        nextimX 124
zpu_next_im125:
        nextimX 125
zpu_next_im126:
        nextimX 126
zpu_next_im127:
        nextimX 127

.section ".data"
idimflag:
        .long 0
.section ".rodata"
dispatchtable:
        .long zpu_ibreak /* opcode 00 */
        .long zpu_fmul16 /* opcode 01 */
        .long zpu_pushsp /* opcode 02 */
        .long zpu_ibreak /* opcode 03 */
        .long zpu_poppc /* opcode 04 */
        .long zpu_add /* opcode 05 */
        .long zpu_and /* opcode 06 */
        .long zpu_or /* opcode 07 */
        .long zpu_load /* opcode 08 */
        .long zpu_not /* opcode 09 */
        .long zpu_flip /* opcode 0a */
        .long zpu_nop /* opcode 0b */
        .long zpu_store /* opcode 0c */
        .long zpu_popsp /* opcode 0d */
        .long zpu_ibreak /* opcode 0e */
        .long zpu_ibreak /* opcode 0f */
        .long zpu_addsp0 /* opcode 10 */
        .long zpu_addsp1 /* opcode 11 */
        .long zpu_addsp2 /* opcode 12 */
        .long zpu_addsp3 /* opcode 13 */
        .long zpu_addsp4 /* opcode 14 */
        .long zpu_addsp5 /* opcode 15 */
        .long zpu_addsp6 /* opcode 16 */
        .long zpu_addsp7 /* opcode 17 */
        .long zpu_addsp8 /* opcode 18 */
        .long zpu_addsp9 /* opcode 19 */
        .long zpu_addsp10 /* opcode 1a */
        .long zpu_addsp11 /* opcode 1b */
        .long zpu_addsp12 /* opcode 1c */
        .long zpu_addsp13 /* opcode 1d */
        .long zpu_addsp14 /* opcode 1e */
        .long zpu_addsp15 /* opcode 1f */
        .long zpu_emulate0 /* opcode 20 */
        .long zpu_emulate1 /* opcode 21 */
        .long zpu_emulate2 /* opcode 22 */
        .long zpu_emulate3 /* opcode 23 */
        .long zpu_emulate4 /* opcode 24 */
        .long zpu_emulate5 /* opcode 25 */
        .long zpu_emulate6 /* opcode 26 */
        .long zpu_emulate7 /* opcode 27 */
        .long zpu_emulate8 /* opcode 28 */
        .long zpu_emulate9 /* opcode 29 */
        .long zpu_emulate10 /* opcode 2a */
        .long zpu_emulate11 /* opcode 2b */
        .long zpu_emulate12 /* opcode 2c */
        .long zpu_emulate13 /* opcode 2d */
        .long zpu_emulate14 /* opcode 2e */
        .long zpu_emulate15 /* opcode 2f */
        .long zpu_emulate16 /* opcode 30 */
        .long zpu_emulate17 /* opcode 31 */
        .long zpu_emulate18 /* opcode 32 */
        .long zpu_emulate19 /* opcode 33 */
        .long zpu_storeb    /* opcode 34 */
        .long zpu_emulate21 /* opcode 35 */
        .long zpu_emulate22 /* opcode 36 */
        .long zpu_emulate23 /* opcode 37 */
        .long zpu_emulate24 /* opcode 38 */
        .long zpu_emulate25 /* opcode 39 */
        .long zpu_emulate26 /* opcode 3a */
        .long zpu_emulate27 /* opcode 3b */
        .long zpu_emulate28 /* opcode 3c */
        .long zpu_emulate29 /* opcode 3d */
        .long zpu_emulate30 /* opcode 3e */
        .long zpu_emulate31 /* opcode 3f */

        .long zpu_storesp16 /* opcode 40 */
        .long zpu_storesp17 /* opcode 41 */
        .long zpu_storesp18 /* opcode 42 */
        .long zpu_storesp19 /* opcode 43 */
        .long zpu_storesp20 /* opcode 44 */
        .long zpu_storesp21 /* opcode 45 */
        .long zpu_storesp22 /* opcode 46 */
        .long zpu_storesp23 /* opcode 47 */
        .long zpu_storesp24 /* opcode 48 */
        .long zpu_storesp25 /* opcode 49 */
        .long zpu_storesp26 /* opcode 4a */
        .long zpu_storesp27 /* opcode 4b */
        .long zpu_storesp28 /* opcode 4c */
        .long zpu_storesp29 /* opcode 4d */
        .long zpu_storesp30 /* opcode 4e */
        .long zpu_storesp31 /* opcode 4f */

        .long zpu_storesp0 /* opcode 50 */
        .long zpu_storesp1 /* opcode 51 */
        .long zpu_storesp2 /* opcode 52 */
        .long zpu_storesp3 /* opcode 53 */
        .long zpu_storesp4 /* opcode 54 */
        .long zpu_storesp5 /* opcode 55 */
        .long zpu_storesp6 /* opcode 56 */
        .long zpu_storesp7 /* opcode 57 */
        .long zpu_storesp8 /* opcode 58 */
        .long zpu_storesp9 /* opcode 59 */
        .long zpu_storesp10 /* opcode 5a */
        .long zpu_storesp11 /* opcode 5b */
        .long zpu_storesp12 /* opcode 5c */
        .long zpu_storesp13 /* opcode 5d */
        .long zpu_storesp14 /* opcode 5e */
        .long zpu_storesp15 /* opcode 5f */

        .long zpu_loadsp16 /* opcode 60 */
        .long zpu_loadsp17 /* opcode 61 */
        .long zpu_loadsp18 /* opcode 62 */
        .long zpu_loadsp19 /* opcode 63 */
        .long zpu_loadsp20 /* opcode 64 */
        .long zpu_loadsp21 /* opcode 65 */
        .long zpu_loadsp22 /* opcode 66 */
        .long zpu_loadsp23 /* opcode 67 */
        .long zpu_loadsp24 /* opcode 68 */
        .long zpu_loadsp25 /* opcode 69 */
        .long zpu_loadsp26 /* opcode 6a */
        .long zpu_loadsp27 /* opcode 6b */
        .long zpu_loadsp28 /* opcode 6c */
        .long zpu_loadsp29 /* opcode 6d */
        .long zpu_loadsp30 /* opcode 6e */
        .long zpu_loadsp31 /* opcode 6f */
        .long zpu_loadsp0 /* opcode 70 */
        .long zpu_loadsp1 /* opcode 71 */
        .long zpu_loadsp2 /* opcode 72 */
        .long zpu_loadsp3 /* opcode 73 */
        .long zpu_loadsp4 /* opcode 74 */
        .long zpu_loadsp5 /* opcode 75 */
        .long zpu_loadsp6 /* opcode 76 */
        .long zpu_loadsp7 /* opcode 77 */
        .long zpu_loadsp8 /* opcode 78 */
        .long zpu_loadsp9 /* opcode 79 */
        .long zpu_loadsp10 /* opcode 7a */
        .long zpu_loadsp11 /* opcode 7b */
        .long zpu_loadsp12 /* opcode 7c */
        .long zpu_loadsp13 /* opcode 7d */
        .long zpu_loadsp14 /* opcode 7e */
        .long zpu_loadsp15 /* opcode 7f */

        .long zpu_first_im0 /* opcode 80 */
        .long zpu_first_im1 /* opcode 81 */
        .long zpu_first_im2 /* opcode 82 */
        .long zpu_first_im3 /* opcode 83 */
        .long zpu_first_im4 /* opcode 84 */
        .long zpu_first_im5 /* opcode 85 */
        .long zpu_first_im6 /* opcode 86 */
        .long zpu_first_im7 /* opcode 87 */
        .long zpu_first_im8 /* opcode 88 */
        .long zpu_first_im9 /* opcode 89 */
        .long zpu_first_im10 /* opcode 8a */
        .long zpu_first_im11 /* opcode 8b */
        .long zpu_first_im12 /* opcode 8c */
        .long zpu_first_im13 /* opcode 8d */
        .long zpu_first_im14 /* opcode 8e */
        .long zpu_first_im15 /* opcode 8f */
        .long zpu_first_im16 /* opcode 90 */
        .long zpu_first_im17 /* opcode 91 */
        .long zpu_first_im18 /* opcode 92 */
        .long zpu_first_im19 /* opcode 93 */
        .long zpu_first_im20 /* opcode 94 */
        .long zpu_first_im21 /* opcode 95 */
        .long zpu_first_im22 /* opcode 96 */
        .long zpu_first_im23 /* opcode 97 */
        .long zpu_first_im24 /* opcode 98 */
        .long zpu_first_im25 /* opcode 99 */
        .long zpu_first_im26 /* opcode 9a */
        .long zpu_first_im27 /* opcode 9b */
        .long zpu_first_im28 /* opcode 9c */
        .long zpu_first_im29 /* opcode 9d */
        .long zpu_first_im30 /* opcode 9e */
        .long zpu_first_im31 /* opcode 9f */
        .long zpu_first_im32 /* opcode a0 */
        .long zpu_first_im33 /* opcode a1 */
        .long zpu_first_im34 /* opcode a2 */
        .long zpu_first_im35 /* opcode a3 */
        .long zpu_first_im36 /* opcode a4 */
        .long zpu_first_im37 /* opcode a5 */
        .long zpu_first_im38 /* opcode a6 */
        .long zpu_first_im39 /* opcode a7 */
        .long zpu_first_im40 /* opcode a8 */
        .long zpu_first_im41 /* opcode a9 */
        .long zpu_first_im42 /* opcode aa */
        .long zpu_first_im43 /* opcode ab */
        .long zpu_first_im44 /* opcode ac */
        .long zpu_first_im45 /* opcode ad */
        .long zpu_first_im46 /* opcode ae */
        .long zpu_first_im47 /* opcode af */
        .long zpu_first_im48 /* opcode b0 */
        .long zpu_first_im49 /* opcode b1 */
        .long zpu_first_im50 /* opcode b2 */
        .long zpu_first_im51 /* opcode b3 */
        .long zpu_first_im52 /* opcode b4 */
        .long zpu_first_im53 /* opcode b5 */
        .long zpu_first_im54 /* opcode b6 */
        .long zpu_first_im55 /* opcode b7 */
        .long zpu_first_im56 /* opcode b8 */
        .long zpu_first_im57 /* opcode b9 */
        .long zpu_first_im58 /* opcode ba */
        .long zpu_first_im59 /* opcode bb */
        .long zpu_first_im60 /* opcode bc */
        .long zpu_first_im61 /* opcode bd */
        .long zpu_first_im62 /* opcode be */
        .long zpu_first_im63 /* opcode bf */

        .long zpu_first_im64 /* opcode c0 */
        .long zpu_first_im65 /* opcode c1 */
        .long zpu_first_im66 /* opcode c2 */
        .long zpu_first_im67 /* opcode c3 */
        .long zpu_first_im68 /* opcode c4 */
        .long zpu_first_im69 /* opcode c5 */
        .long zpu_first_im70 /* opcode c6 */
        .long zpu_first_im71 /* opcode c7 */
        .long zpu_first_im72 /* opcode c8 */
        .long zpu_first_im73 /* opcode c9 */
        .long zpu_first_im74 /* opcode ca */
        .long zpu_first_im75 /* opcode cb */
        .long zpu_first_im76 /* opcode cc */
        .long zpu_first_im77 /* opcode cd */
        .long zpu_first_im78 /* opcode ce */
        .long zpu_first_im79 /* opcode cf */
        .long zpu_first_im80 /* opcode d0 */
        .long zpu_first_im81 /* opcode d1 */
        .long zpu_first_im82 /* opcode d2 */
        .long zpu_first_im83 /* opcode d3 */
        .long zpu_first_im84 /* opcode d4 */
        .long zpu_first_im85 /* opcode d5 */
        .long zpu_first_im86 /* opcode d6 */
        .long zpu_first_im87 /* opcode d7 */
        .long zpu_first_im88 /* opcode d8 */
        .long zpu_first_im89 /* opcode d9 */
        .long zpu_first_im90 /* opcode da */
        .long zpu_first_im91 /* opcode db */
        .long zpu_first_im92 /* opcode dc */
        .long zpu_first_im93 /* opcode dd */
        .long zpu_first_im94 /* opcode de */
        .long zpu_first_im95 /* opcode df */
        .long zpu_first_im96 /* opcode e0 */
        .long zpu_first_im97 /* opcode e1 */
        .long zpu_first_im98 /* opcode e2 */
        .long zpu_first_im99 /* opcode e3 */
        .long zpu_first_im100 /* opcode e4 */
        .long zpu_first_im101 /* opcode e5 */
        .long zpu_first_im102 /* opcode e6 */
        .long zpu_first_im103 /* opcode e7 */
        .long zpu_first_im104 /* opcode e8 */
        .long zpu_first_im105 /* opcode e9 */
        .long zpu_first_im106 /* opcode ea */
        .long zpu_first_im107 /* opcode eb */
        .long zpu_first_im108 /* opcode ec */
        .long zpu_first_im109 /* opcode ed */
        .long zpu_first_im110 /* opcode ee */
        .long zpu_first_im111 /* opcode ef */
        .long zpu_first_im112 /* opcode f0 */
        .long zpu_first_im113 /* opcode f1 */
        .long zpu_first_im114 /* opcode f2 */
        .long zpu_first_im115 /* opcode f3 */
        .long zpu_first_im116 /* opcode f4 */
        .long zpu_first_im117 /* opcode f5 */
        .long zpu_first_im118 /* opcode f6 */
        .long zpu_first_im119 /* opcode f7 */
        .long zpu_first_im120 /* opcode f8 */
        .long zpu_first_im121 /* opcode f9 */
        .long zpu_first_im122 /* opcode fa */
        .long zpu_first_im123 /* opcode fb */
        .long zpu_first_im124 /* opcode fc */
        .long zpu_first_im125 /* opcode fd */
        .long zpu_first_im126 /* opcode fe */
        .long zpu_first_im127 /* opcode ff */
/* IDIM version */
        .long zpu_ibreak /* opcode 00 */
        .long zpu_ibreak /* opcode 01 */
        .long zpu_pushsp /* opcode 02 */
        .long zpu_ibreak /* opcode 03 */
        .long zpu_poppc /* opcode 04 */
        .long zpu_add /* opcode 05 */
        .long zpu_and /* opcode 06 */
        .long zpu_or /* opcode 07 */
        .long zpu_load /* opcode 08 */
        .long zpu_not /* opcode 09 */
        .long zpu_flip /* opcode 0a */
        .long zpu_nop /* opcode 0b */
        .long zpu_store /* opcode 0c */
        .long zpu_popsp /* opcode 0d */
        .long zpu_ibreak /* opcode 0e */
        .long zpu_ibreak /* opcode 0f */
        .long zpu_addsp0 /* opcode 10 */
        .long zpu_addsp1 /* opcode 11 */
        .long zpu_addsp2 /* opcode 12 */
        .long zpu_addsp3 /* opcode 13 */
        .long zpu_addsp4 /* opcode 14 */
        .long zpu_addsp5 /* opcode 15 */
        .long zpu_addsp6 /* opcode 16 */
        .long zpu_addsp7 /* opcode 17 */
        .long zpu_addsp8 /* opcode 18 */
        .long zpu_addsp9 /* opcode 19 */
        .long zpu_addsp10 /* opcode 1a */
        .long zpu_addsp11 /* opcode 1b */
        .long zpu_addsp12 /* opcode 1c */
        .long zpu_addsp13 /* opcode 1d */
        .long zpu_addsp14 /* opcode 1e */
        .long zpu_addsp15 /* opcode 1f */
        .long zpu_emulate0 /* opcode 20 */
        .long zpu_emulate1 /* opcode 21 */
        .long zpu_emulate2 /* opcode 22 */
        .long zpu_emulate3 /* opcode 23 */
        .long zpu_emulate4 /* opcode 24 */
        .long zpu_emulate5 /* opcode 25 */
        .long zpu_emulate6 /* opcode 26 */
        .long zpu_emulate7 /* opcode 27 */
        .long zpu_emulate8 /* opcode 28 */
        .long zpu_emulate9 /* opcode 29 */
        .long zpu_emulate10 /* opcode 2a */
        .long zpu_emulate11 /* opcode 2b */
        .long zpu_emulate12 /* opcode 2c */
        .long zpu_emulate13 /* opcode 2d */
        .long zpu_emulate14 /* opcode 2e */
        .long zpu_emulate15 /* opcode 2f */
        .long zpu_emulate16 /* opcode 30 */
        .long zpu_emulate17 /* opcode 31 */
        .long zpu_emulate18 /* opcode 32 */
        .long zpu_emulate19 /* opcode 33 */
        .long zpu_emulate20 /* opcode 34 */
        .long zpu_emulate21 /* opcode 35 */
        .long zpu_emulate22 /* opcode 36 */
        .long zpu_emulate23 /* opcode 37 */
        .long zpu_emulate24 /* opcode 38 */
        .long zpu_emulate25 /* opcode 39 */
        .long zpu_emulate26 /* opcode 3a */
        .long zpu_emulate27 /* opcode 3b */
        .long zpu_emulate28 /* opcode 3c */
        .long zpu_emulate29 /* opcode 3d */
        .long zpu_emulate30 /* opcode 3e */
        .long zpu_emulate31 /* opcode 3f */

        .long zpu_storesp16 /* opcode 40 */
        .long zpu_storesp17 /* opcode 41 */
        .long zpu_storesp18 /* opcode 42 */
        .long zpu_storesp19 /* opcode 43 */
        .long zpu_storesp20 /* opcode 44 */
        .long zpu_storesp21 /* opcode 45 */
        .long zpu_storesp22 /* opcode 46 */
        .long zpu_storesp23 /* opcode 47 */
        .long zpu_storesp24 /* opcode 48 */
        .long zpu_storesp25 /* opcode 49 */
        .long zpu_storesp26 /* opcode 4a */
        .long zpu_storesp27 /* opcode 4b */
        .long zpu_storesp28 /* opcode 4c */
        .long zpu_storesp29 /* opcode 4d */
        .long zpu_storesp30 /* opcode 4e */
        .long zpu_storesp31 /* opcode 4f */

        .long zpu_storesp0 /* opcode 50 */
        .long zpu_storesp1 /* opcode 51 */
        .long zpu_storesp2 /* opcode 52 */
        .long zpu_storesp3 /* opcode 53 */
        .long zpu_storesp4 /* opcode 54 */
        .long zpu_storesp5 /* opcode 55 */
        .long zpu_storesp6 /* opcode 56 */
        .long zpu_storesp7 /* opcode 57 */
        .long zpu_storesp8 /* opcode 58 */
        .long zpu_storesp9 /* opcode 59 */
        .long zpu_storesp10 /* opcode 5a */
        .long zpu_storesp11 /* opcode 5b */
        .long zpu_storesp12 /* opcode 5c */
        .long zpu_storesp13 /* opcode 5d */
        .long zpu_storesp14 /* opcode 5e */
        .long zpu_storesp15 /* opcode 5f */


        .long zpu_loadsp16 /* opcode 60 */
        .long zpu_loadsp17 /* opcode 61 */
        .long zpu_loadsp18 /* opcode 62 */
        .long zpu_loadsp19 /* opcode 63 */
        .long zpu_loadsp20 /* opcode 64 */
        .long zpu_loadsp21 /* opcode 65 */
        .long zpu_loadsp22 /* opcode 66 */
        .long zpu_loadsp23 /* opcode 67 */
        .long zpu_loadsp24 /* opcode 68 */
        .long zpu_loadsp25 /* opcode 69 */
        .long zpu_loadsp26 /* opcode 6a */
        .long zpu_loadsp27 /* opcode 6b */
        .long zpu_loadsp28 /* opcode 6c */
        .long zpu_loadsp29 /* opcode 6d */
        .long zpu_loadsp30 /* opcode 6e */
        .long zpu_loadsp31 /* opcode 6f */
        .long zpu_loadsp0 /* opcode 70 */
        .long zpu_loadsp1 /* opcode 71 */
        .long zpu_loadsp2 /* opcode 72 */
        .long zpu_loadsp3 /* opcode 73 */
        .long zpu_loadsp4 /* opcode 74 */
        .long zpu_loadsp5 /* opcode 75 */
        .long zpu_loadsp6 /* opcode 76 */
        .long zpu_loadsp7 /* opcode 77 */
        .long zpu_loadsp8 /* opcode 78 */
        .long zpu_loadsp9 /* opcode 79 */
        .long zpu_loadsp10 /* opcode 7a */
        .long zpu_loadsp11 /* opcode 7b */
        .long zpu_loadsp12 /* opcode 7c */
        .long zpu_loadsp13 /* opcode 7d */
        .long zpu_loadsp14 /* opcode 7e */
        .long zpu_loadsp15 /* opcode 7f */

        .long zpu_next_im0 /* opcode 80 */
        .long zpu_next_im1 /* opcode 81 */
        .long zpu_next_im2 /* opcode 82 */
        .long zpu_next_im3 /* opcode 83 */
        .long zpu_next_im4 /* opcode 84 */
        .long zpu_next_im5 /* opcode 85 */
        .long zpu_next_im6 /* opcode 86 */
        .long zpu_next_im7 /* opcode 87 */
        .long zpu_next_im8 /* opcode 88 */
        .long zpu_next_im9 /* opcode 89 */
        .long zpu_next_im10 /* opcode 8a */
        .long zpu_next_im11 /* opcode 8b */
        .long zpu_next_im12 /* opcode 8c */
        .long zpu_next_im13 /* opcode 8d */
        .long zpu_next_im14 /* opcode 8e */
        .long zpu_next_im15 /* opcode 8f */
        .long zpu_next_im16 /* opcode 90 */
        .long zpu_next_im17 /* opcode 91 */
        .long zpu_next_im18 /* opcode 92 */
        .long zpu_next_im19 /* opcode 93 */
        .long zpu_next_im20 /* opcode 94 */
        .long zpu_next_im21 /* opcode 95 */
        .long zpu_next_im22 /* opcode 96 */
        .long zpu_next_im23 /* opcode 97 */
        .long zpu_next_im24 /* opcode 98 */
        .long zpu_next_im25 /* opcode 99 */
        .long zpu_next_im26 /* opcode 9a */
        .long zpu_next_im27 /* opcode 9b */
        .long zpu_next_im28 /* opcode 9c */
        .long zpu_next_im29 /* opcode 9d */
        .long zpu_next_im30 /* opcode 9e */
        .long zpu_next_im31 /* opcode 9f */
        .long zpu_next_im32 /* opcode a0 */
        .long zpu_next_im33 /* opcode a1 */
        .long zpu_next_im34 /* opcode a2 */
        .long zpu_next_im35 /* opcode a3 */
        .long zpu_next_im36 /* opcode a4 */
        .long zpu_next_im37 /* opcode a5 */
        .long zpu_next_im38 /* opcode a6 */
        .long zpu_next_im39 /* opcode a7 */
        .long zpu_next_im40 /* opcode a8 */
        .long zpu_next_im41 /* opcode a9 */
        .long zpu_next_im42 /* opcode aa */
        .long zpu_next_im43 /* opcode ab */
        .long zpu_next_im44 /* opcode ac */
        .long zpu_next_im45 /* opcode ad */
        .long zpu_next_im46 /* opcode ae */
        .long zpu_next_im47 /* opcode af */
        .long zpu_next_im48 /* opcode b0 */
        .long zpu_next_im49 /* opcode b1 */
        .long zpu_next_im50 /* opcode b2 */
        .long zpu_next_im51 /* opcode b3 */
        .long zpu_next_im52 /* opcode b4 */
        .long zpu_next_im53 /* opcode b5 */
        .long zpu_next_im54 /* opcode b6 */
        .long zpu_next_im55 /* opcode b7 */
        .long zpu_next_im56 /* opcode b8 */
        .long zpu_next_im57 /* opcode b9 */
        .long zpu_next_im58 /* opcode ba */
        .long zpu_next_im59 /* opcode bb */
        .long zpu_next_im60 /* opcode bc */
        .long zpu_next_im61 /* opcode bd */
        .long zpu_next_im62 /* opcode be */
        .long zpu_next_im63 /* opcode bf */

        .long zpu_next_im64 /* opcode c0 */
        .long zpu_next_im65 /* opcode c1 */
        .long zpu_next_im66 /* opcode c2 */
        .long zpu_next_im67 /* opcode c3 */
        .long zpu_next_im68 /* opcode c4 */
        .long zpu_next_im69 /* opcode c5 */
        .long zpu_next_im70 /* opcode c6 */
        .long zpu_next_im71 /* opcode c7 */
        .long zpu_next_im72 /* opcode c8 */
        .long zpu_next_im73 /* opcode c9 */
        .long zpu_next_im74 /* opcode ca */
        .long zpu_next_im75 /* opcode cb */
        .long zpu_next_im76 /* opcode cc */
        .long zpu_next_im77 /* opcode cd */
        .long zpu_next_im78 /* opcode ce */
        .long zpu_next_im79 /* opcode cf */
        .long zpu_next_im80 /* opcode d0 */
        .long zpu_next_im81 /* opcode d1 */
        .long zpu_next_im82 /* opcode d2 */
        .long zpu_next_im83 /* opcode d3 */
        .long zpu_next_im84 /* opcode d4 */
        .long zpu_next_im85 /* opcode d5 */
        .long zpu_next_im86 /* opcode d6 */
        .long zpu_next_im87 /* opcode d7 */
        .long zpu_next_im88 /* opcode d8 */
        .long zpu_next_im89 /* opcode d9 */
        .long zpu_next_im90 /* opcode da */
        .long zpu_next_im91 /* opcode db */
        .long zpu_next_im92 /* opcode dc */
        .long zpu_next_im93 /* opcode dd */
        .long zpu_next_im94 /* opcode de */
        .long zpu_next_im95 /* opcode df */
        .long zpu_next_im96 /* opcode e0 */
        .long zpu_next_im97 /* opcode e1 */
        .long zpu_next_im98 /* opcode e2 */
        .long zpu_next_im99 /* opcode e3 */
        .long zpu_next_im100 /* opcode e4 */
        .long zpu_next_im101 /* opcode e5 */
        .long zpu_next_im102 /* opcode e6 */
        .long zpu_next_im103 /* opcode e7 */
        .long zpu_next_im104 /* opcode e8 */
        .long zpu_next_im105 /* opcode e9 */
        .long zpu_next_im106 /* opcode ea */
        .long zpu_next_im107 /* opcode eb */
        .long zpu_next_im108 /* opcode ec */
        .long zpu_next_im109 /* opcode ed */
        .long zpu_next_im110 /* opcode ee */
        .long zpu_next_im111 /* opcode ef */
        .long zpu_next_im112 /* opcode f0 */
        .long zpu_next_im113 /* opcode f1 */
        .long zpu_next_im114 /* opcode f2 */
        .long zpu_next_im115 /* opcode f3 */
        .long zpu_next_im116 /* opcode f4 */
        .long zpu_next_im117 /* opcode f5 */
        .long zpu_next_im118 /* opcode f6 */
        .long zpu_next_im119 /* opcode f7 */
        .long zpu_next_im120 /* opcode f8 */
        .long zpu_next_im121 /* opcode f9 */
        .long zpu_next_im122 /* opcode fa */
        .long zpu_next_im123 /* opcode fb */
        .long zpu_next_im124 /* opcode fc */
        .long zpu_next_im125 /* opcode fd */
        .long zpu_next_im126 /* opcode fe */
        .long zpu_next_im127 /* opcode ff */
