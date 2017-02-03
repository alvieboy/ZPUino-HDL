	.file	"boot.cpp"
	.globl	vstring
	.section	.data.vstring,"aw",@progbits
	.balign 4;
	.type	vstring, @object
	.size	vstring, 20
vstring:
	.byte	1
	.byte	9
	.byte	6
	.byte	0
	.byte	0
	.byte	0
	.byte	0
	.byte	0
	.byte	5
	.byte	-72
	.byte	-40
	.byte	0
	.byte	-76
	.byte	4
	.byte	23
	.byte	0
	.byte	0
	.byte	0
	.byte	0
	.byte	0
	.globl	bdata
	.section	.bss.bdata,"aw",@nobits
	.balign 4;
	.type	bdata, @object
	.size	bdata, 12
bdata:
	.zero	12
	.section	.bss.milisseconds,"aw",@nobits
	.balign 4;
	.type	milisseconds, @object
	.size	milisseconds, 4
milisseconds:
	.zero	4
	.section	.bss.inprogrammode,"aw",@nobits
	.balign 4;
	.type	inprogrammode, @object
	.size	inprogrammode, 4
inprogrammode:
	.zero	4
	.section	.rodata.handlers,"a",@progbits
	.balign 4;
	.type	handlers, @object
	.size	handlers, 40
handlers:
	.long	_Z11cmd_versionPh
	.long	_Z12cmd_identifyPh
	.long	_Z13cmd_waitreadyPh
	.long	_Z20cmd_raw_send_receivePh
	.long	_Z12cmd_enterpgmPh
	.long	_Z12cmd_leavepgmPh
	.long	_Z19cmd_sst_aai_programPh
	.long	_Z16cmd_set_baudratePh
	.long	_Z11cmd_progmemPh
	.long	_Z9cmd_startPh
	.section	.bss.flash_id,"aw",@nobits
	.balign 4;
	.type	flash_id, @object
	.size	flash_id, 4
flash_id:
	.zero	4
	.section	.text._Z5flushv,"ax",@progbits
	.globl	_Z5flushv
	.type	_Z5flushv, @function
_Z5flushv:
	im -1
	pushspadd
	popsp
	im 142606340
	storesp 8
.L2:
	loadsp 4
	load
	loadsp 0
	im 2
	lshiftright
	loadsp 0
	im 1
	and
	storesp 4
	storesp 4
	storesp 4
	loadsp 0
	impcrel .L2
	neqbranch
	im 3
	pushspadd
	popsp
	poppc
	.size	_Z5flushv, .-_Z5flushv
	.section	.text.putc,"ax",@progbits
	.globl	putc
	.type	putc, @function
putc:
	im -1
	pushspadd
	popsp
	im 142606340
	storesp 8
.L6:
	loadsp 4
	load
	loadsp 0
	im 1
	lshiftright
	loadsp 0
	im 1
	and
	storesp 4
	storesp 4
	storesp 4
	loadsp 0
	impcrel .L6
	neqbranch
	loadsp 12
	im 142606336
	store
	im 3
	pushspadd
	popsp
	poppc
	.size	putc, .-putc
	.section	.text._Z7outbytei,"ax",@progbits
	.type	_Z7outbytei, @function
_Z7outbytei:
	im -1
	pushspadd
	popsp
	im 142606340
	storesp 8
.L10:
	loadsp 4
	load
	loadsp 0
	im 1
	lshiftright
	loadsp 0
	im 1
	and
	storesp 4
	storesp 4
	storesp 4
	loadsp 0
	impcrel .L10
	neqbranch
	loadsp 12
	im 142606336
	store
	im 3
	pushspadd
	popsp
	poppc
	.size	_Z7outbytei, .-_Z7outbytei
	.section	.text.printnibble,"ax",@progbits
	.globl	printnibble
	.type	printnibble, @function
printnibble:
	im -1
	pushspadd
	popsp
	loadsp 12
	im 15
	and
	storesp 8
	im 9
	loadsp 8
	ulessthanorequal
	impcrel .L14
	neqbranch
	im 87
	addsp 8
	storesp 4
	impcrel .L16
	poppcrel
.L14:
	im 48
	addsp 8
	storesp 4
.L16:
	im _Z7outbytei
	call
	im 3
	pushspadd
	popsp
	poppc
	.size	printnibble, .-printnibble
	.section	.text.printstring,"ax",@progbits
	.globl	printstring
	.type	printstring, @function
printstring:
	im -3
	pushspadd
	popsp
	loadsp 20
	storesp 16
.L23:
	loadsp 12
	loadb
	loadsp 0
	im 0xff
	and
	storesp 12
	storesp 12
	loadsp 4
	im 0
	eq
	impcrel .L22
	neqbranch
	loadsp 8
	im 0xff
	and
	storesp 4
	im _Z7outbytei
	call
	im 1
	addsp 16
	storesp 16
	impcrel .L23
	poppcrel
.L22:
	im 5
	pushspadd
	popsp
	poppc
	.size	printstring, .-printstring
	.section	.text.printhexbyte,"ax",@progbits
	.globl	printhexbyte
	.type	printhexbyte, @function
printhexbyte:
	im -1
	pushspadd
	popsp
	loadsp 12
	loadsp 0
	im 4
	lshiftright
	storesp 8
	storesp 8
	im printnibble
	call
	loadsp 4
	storesp 4
	im printnibble
	call
	im 3
	pushspadd
	popsp
	poppc
	.size	printhexbyte, .-printhexbyte
	.section	.text.printhex,"ax",@progbits
	.globl	printhex
	.type	printhex, @function
printhex:
	im -1
	pushspadd
	popsp
	loadsp 12
	loadsp 0
	im 24
	lshiftright
	storesp 8
	storesp 8
	im printhexbyte
	call
	loadsp 4
	im 16
	lshiftright
	storesp 4
	im printhexbyte
	call
	loadsp 4
	im 8
	lshiftright
	storesp 4
	im printhexbyte
	call
	loadsp 4
	storesp 4
	im printhexbyte
	call
	im 3
	pushspadd
	popsp
	poppc
	.size	printhex, .-printhex
	.section	.text._Z8sendBytej,"ax",@progbits
	.globl	_Z8sendBytej
	.type	_Z8sendBytej, @function
_Z8sendBytej:
	im -2
	pushspadd
	popsp
	loadsp 16
	loadsp 0
	im 192937992
	store
	loadsp 0
	im 255
	and
	im -125
	addsp 4
	storesp 16
	storesp 4
	storesp 12
	loadsp 4
	im 1
	ulessthan
	impcrel .L27
	neqbranch
	im 125
	storesp 4
	im _Z7outbytei
	call
	loadsp 8
	im 32
	xor
	storesp 4
	impcrel .L29
	poppcrel
.L27:
	loadsp 8
	storesp 4
.L29:
	im _Z7outbytei
	call
	im 4
	pushspadd
	popsp
	poppc
	.size	_Z8sendBytej, .-_Z8sendBytej
	.section	.text._Z11prepareSendv,"ax",@progbits
	.type	_Z11prepareSendv, @function
_Z11prepareSendv:
	im 0
	pushspadd
	popsp
	im 65535
	nop
	im 192937984
	store
	im 126
	storesp 4
	im _Z7outbytei
	call
	im 2
	pushspadd
	popsp
	poppc
	.size	_Z11prepareSendv, .-_Z11prepareSendv
	.section	.text._Z10finishSendv,"ax",@progbits
	.globl	_Z10finishSendv
	.type	_Z10finishSendv, @function
_Z10finishSendv:
	im -1
	pushspadd
	popsp
	im 192937984
	load
	loadsp 0
	im 8
	lshiftright
	storesp 8
	storesp 8
	im _Z8sendBytej
	call
	loadsp 4
	im 0xff
	and
	storesp 4
	im _Z8sendBytej
	call
	im 126
	storesp 4
	im _Z7outbytei
	call
	im 3
	pushspadd
	popsp
	poppc
	.size	_Z10finishSendv, .-_Z10finishSendv
	.section	.text._Z11enableTimerv,"ax",@progbits
	.type	_Z11enableTimerv, @function
_Z11enableTimerv:
	im 47999
	nop
	im 159383560
	store
	im 0
	nop
	im 159383556
	store
	im 31
	nop
	im 159383552
	store
	poppc
	.size	_Z11enableTimerv, .-_Z11enableTimerv
	.section	.text._Z11spi_disablePVj,"ax",@progbits
	.type	_Z11spi_disablePVj, @function
_Z11spi_disablePVj:
	im -1
	pushspadd
	popsp
	loadsp 12
	loadsp 0
	load
	storesp 4
	storesp 4
	im 150994948
	loadsp 0
	load
	loadsp 0
	im 65536
	or
	loadsp 8
	store
	storesp 8
	storesp 8
	im 3
	pushspadd
	popsp
	poppc
	.size	_Z11spi_disablePVj, .-_Z11spi_disablePVj
	.section	.text._Z10spi_enablev,"ax",@progbits
	.type	_Z10spi_enablev, @function
_Z10spi_enablev:
	im -1
	pushspadd
	popsp
	im 150994948
	loadsp 0
	load
	loadsp 0
	im -65537
	and
	loadsp 8
	store
	storesp 8
	storesp 8
	im 3
	pushspadd
	popsp
	poppc
	.size	_Z10spi_enablev, .-_Z10spi_enablev
	.section	.text.start,"ax",@progbits
	.globl	start
	.type	start, @function
start:
	im 4112
	nop
	im ivector
	store
	im bdata
	nop
	im bootloaderdata
	store
	im start_sketch
	call
	.size	start, .-start
	.section	.text._Z15start_read_sizePVj,"ax",@progbits
	.type	_Z15start_read_sizePVj, @function
_Z15start_read_sizePVj:
	im -1
	pushspadd
	popsp
	loadsp 12
	storesp 4
	im 11
	loadsp 4
	store
	im 16
	addsp 4
	storesp 8
	im 393216
	loadsp 8
	store
	im 0
	loadsp 8
	store
	loadsp 0
	load
	im 65535
	and
	im _memreg+0
	store
	im 3
	pushspadd
	popsp
	poppc
	.size	_Z15start_read_sizePVj, .-_Z15start_read_sizePVj
	.section	.text.copy_sketch,"ax",@progbits
	.globl	copy_sketch
	.type	copy_sketch, @function
copy_sketch:
	im -6
	pushspadd
	popsp
	loadsp 32
	loadsp 40
	loadsp 52
	im -1
	addsp 56
	storesp 28
	storesp 28
	storesp 32
	storesp 12
	loadsp 12
	im -1
	eq
	impcrel .L74
	neqbranch
	im 0
	storesp 24
.L72:
	im 4
	storesp 8
.L69:
	loadsp 20
	loadsp 12
	store
	loadsp 8
	load
	im 8
	addsp 32
	store
	im -1
	addsp 8
	storesp 8
	loadsp 4
	impcrel .L69
	neqbranch
	loadsp 16
	im 4
	addsp 24
	loadsp 16
	load
	loadsp 8
	store
	im -1
	addsp 24
	storesp 24
	storesp 24
	storesp 8
	loadsp 12
	im -1
	eq
	not
	im 1
	and
	impcrel .L72
	neqbranch
.L74:
	im 8
	pushspadd
	popsp
	poppc
	.size	copy_sketch, .-copy_sketch
	.section	.text.spi_copy_impl,"ax",@progbits
	.globl	spi_copy_impl
	.type	spi_copy_impl, @function
spi_copy_impl:
	im -7
	pushspadd
	popsp
	im 167772164
	storesp 24
	im 192937984
	storesp 32
	im _Z10spi_enablev
	call
	loadsp 20
	storesp 4
	im _Z15start_read_sizePVj
	call
	im bdata
	loadsp 0
	im _memreg+0
	load
	addsp 0
	addsp 0
	im 393220
	add
	loadsp 4
	loadsp 0
	im 4
	add
	storesp 12
	store
	storesp 24
	storesp 28
	im -1342107475
	loadsp 20
	store
	im vstring
	nop
	im 8
	addsp 32
	store
	im 0
	loadsp 0
	loadsp 28
	store
	loadsp 24
	store
	loadsp 20
	load
	loadsp 0
	im 65535
	and
	storesp 4
	storesp 28
	im 65535
	loadsp 32
	store
	im 4096
	storesp 16
	im _memreg+0
	load
	storesp 12
	loadsp 28
	storesp 8
	loadsp 20
	storesp 4
	im copy_sketch
	call
	loadsp 20
	storesp 4
	im _Z11spi_disablePVj
	call
	loadsp 28
	load
	storesp 20
	loadsp 16
	loadsp 28
	eq
	impcrel .L84
	neqbranch
	im 67
	storesp 4
	im _Z7outbytei
	call
.L85:
	impcrel .L85
	poppcrel
.L84:
	im 4100
	load
	storesp 20
	loadsp 16
	im -1274800384
	eq
	impcrel .L87
	neqbranch
	im 66
	storesp 4
	im _Z7outbytei
	call
.L88:
	impcrel .L88
	poppcrel
.L87:
	im 167772160
	loadsp 0
	load
	loadsp 0
	im -65
	and
	loadsp 8
	store
	storesp 24
	storesp 24
	im _Z5flushv
	call
	im start
	call
	.size	spi_copy_impl, .-spi_copy_impl
	.section	.text._zpu_interrupt,"ax",@progbits
	.globl	_zpu_interrupt
	.type	_zpu_interrupt, @function
_zpu_interrupt:
	im -1
	pushspadd
	popsp
	im milisseconds
	load
	im 1
	addsp 4
	im milisseconds
	store
	storesp 4
	im 159383552
	loadsp 0
	load
	loadsp 0
	im -129
	and
	loadsp 8
	store
	storesp 8
	storesp 8
	im 3
	pushspadd
	popsp
	poppc
	.size	_zpu_interrupt, .-_zpu_interrupt
	.section	.text._Z11simpleReplyj,"ax",@progbits
	.type	_Z11simpleReplyj, @function
_Z11simpleReplyj:
	im 0
	pushspadd
	popsp
	im _Z11prepareSendv
	call
	loadsp 8
	im 128
	or
	storesp 4
	im _Z8sendBytej
	call
	im _Z10finishSendv
	call
	im 2
	pushspadd
	popsp
	poppc
	.size	_Z11simpleReplyj, .-_Z11simpleReplyj
	.section	.text._Z15spi_read_statusv,"ax",@progbits
	.type	_Z15spi_read_statusv, @function
_Z15spi_read_statusv:
	im -2
	pushspadd
	popsp
	im 167772164
	storesp 12
	im _Z10spi_enablev
	call
	im 5
	loadsp 12
	store
	im 0
	loadsp 12
	store
	loadsp 8
	load
	loadsp 0
	im 255
	and
	loadsp 16
	storesp 12
	storesp 4
	storesp 8
	im _Z11spi_disablePVj
	call
	loadsp 4
	im _memreg+0
	store
	im 4
	pushspadd
	popsp
	poppc
	.size	_Z15spi_read_statusv, .-_Z15spi_read_statusv
	.section	.text._Z11cmd_progmemPh,"ax",@progbits
	.type	_Z11cmd_progmemPh, @function
_Z11cmd_progmemPh:
	im -4
	pushspadd
	popsp
	loadsp 24
	im 1
	addsp 4
	loadb
	im 2
	addsp 8
	loadb
	loadsp 4
	im 16777216
	mult
	loadsp 4
	im 65536
	mult
	add
	im 3
	addsp 16
	loadb
	loadsp 0
	im 256
	mult
	addsp 8
	im 4
	addsp 24
	loadb
	storesp 8
	loadsp 4
	add
	im 4096
	add
	im 6
	addsp 24
	im 5
	addsp 28
	loadb
	storesp 28
	storesp 8
	storesp 12
	storesp 12
	storesp 20
	storesp 28
	storesp 20
	storesp 12
.L107:
	im -1
	addsp 12
	storesp 12
	loadsp 8
	im -1
	eq
	impcrel .L106
	neqbranch
	loadsp 12
	loadsp 0
	im 1
	add
	storesp 20
	loadb
	storesp 8
	loadsp 4
	loadsp 20
	loadsp 0
	im 1
	add
	storesp 28
	storeb
	impcrel .L107
	poppcrel
.L106:
	im 9
	storesp 4
	im _Z11simpleReplyj
	call
	im 6
	pushspadd
	popsp
	poppc
	.size	_Z11cmd_progmemPh, .-_Z11cmd_progmemPh
	.section	.text._Z20cmd_raw_send_receivePh,"ax",@progbits
	.type	_Z20cmd_raw_send_receivePh, @function
_Z20cmd_raw_send_receivePh:
	im -7
	pushspadd
	popsp
	loadsp 36
	storesp 28
	im 167772164
	storesp 24
	im _Z10spi_enablev
	call
	im 1
	addsp 28
	loadb
	im 2
	addsp 32
	loadb
	loadsp 4
	im 256
	mult
	add
	storesp 12
	storesp 12
	loadsp 4
	im 0
	eq
	impcrel .L128
	neqbranch
	im 5
	addsp 28
	loadsp 8
	storesp 20
	storesp 12
.L114:
	loadsp 8
	loadsp 0
	im 1
	add
	storesp 16
	loadb
	loadsp 24
	store
	im -1
	addsp 16
	storesp 16
	loadsp 12
	impcrel .L114
	neqbranch
.L128:
	im 3
	addsp 28
	loadb
	im 4
	addsp 32
	loadb
	loadsp 4
	im 256
	mult
	add
	storesp 24
	storesp 8
	im 0
	storesp 16
	loadsp 12
	loadsp 20
	ulessthanorequal
	impcrel .L130
	neqbranch
	loadsp 12
	storesp 32
.L122:
	loadsp 28
	loadsp 24
	store
	loadsp 24
	addsp 16
	loadsp 24
	load
	storesp 12
	storesp 12
	loadsp 4
	loadsp 12
	storeb
	im 1
	addsp 16
	storesp 16
	loadsp 16
	loadsp 16
	ulessthan
	impcrel .L122
	neqbranch
.L130:
	loadsp 20
	storesp 4
	im _Z11spi_disablePVj
	call
	im _Z11prepareSendv
	call
	im 132
	storesp 4
	im _Z8sendBytej
	call
	loadsp 16
	im 8
	lshiftright
	storesp 4
	im _Z8sendBytej
	call
	loadsp 16
	storesp 4
	im _Z8sendBytej
	call
	im 0
	storesp 16
.L133:
	loadsp 12
	loadsp 20
	ulessthanorequal
	impcrel .L132
	neqbranch
	loadsp 24
	addsp 16
	loadsp 0
	loadb
	storesp 8
	storesp 8
	im _Z8sendBytej
	call
	im 1
	addsp 16
	storesp 16
	impcrel .L133
	poppcrel
.L132:
	im _Z10finishSendv
	call
	im 9
	pushspadd
	popsp
	poppc
	.size	_Z20cmd_raw_send_receivePh, .-_Z20cmd_raw_send_receivePh
	.section	.text._Z19cmd_sst_aai_programPh,"ax",@progbits
	.type	_Z19cmd_sst_aai_programPh, @function
_Z19cmd_sst_aai_programPh:
	im -7
	pushspadd
	popsp
	loadsp 36
	storesp 24
	im 167772164
	storesp 20
	im _Z10spi_enablev
	call
	im 6
	loadsp 20
	store
	loadsp 16
	storesp 4
	im _Z11spi_disablePVj
	call
	im _Z10spi_enablev
	call
	im 173
	loadsp 0
	loadsp 24
	store
	im 1
	addsp 28
	loadb
	im 2
	addsp 32
	loadb
	loadsp 4
	im 256
	mult
	add
	im 3
	addsp 36
	loadb
	loadsp 32
	store
	im 4
	addsp 36
	loadb
	loadsp 32
	store
	im 5
	addsp 36
	loadb
	loadsp 32
	store
	storesp 36
	storesp 12
	storesp 12
	im 0
	storesp 16
	loadsp 12
	loadsp 28
	ulessthanorequal
	impcrel .L162
	neqbranch
	loadsp 8
	storesp 32
.L158:
	loadsp 12
	im 0
	eq
	impcrel .L148
	neqbranch
	im _Z10spi_enablev
	call
	loadsp 28
	loadsp 20
	store
.L148:
	loadsp 12
	addsp 24
	im 6
	addsp 4
	loadb
	loadsp 24
	store
	im 7
	addsp 4
	loadb
	loadsp 24
	store
	storesp 8
	loadsp 16
	storesp 4
	im _Z11spi_disablePVj
	call
.L155:
	im _Z15spi_read_statusv
	call
	im _memreg+0
	load
	im 1
	and
	storesp 8
	loadsp 4
	impcrel .L155
	neqbranch
	im 2
	addsp 16
	storesp 16
	loadsp 24
	loadsp 16
	ulessthan
	impcrel .L158
	neqbranch
.L162:
	im _Z10spi_enablev
	call
	im 4
	loadsp 20
	store
	loadsp 16
	storesp 4
	im _Z11spi_disablePVj
	call
	im _Z11prepareSendv
	call
	im 135
	storesp 4
	im _Z8sendBytej
	call
	im _Z10finishSendv
	call
	im 9
	pushspadd
	popsp
	poppc
	.size	_Z19cmd_sst_aai_programPh, .-_Z19cmd_sst_aai_programPh
	.section	.text._Z16cmd_set_baudratePh,"ax",@progbits
	.type	_Z16cmd_set_baudratePh, @function
_Z16cmd_set_baudratePh:
	im -4
	pushspadd
	popsp
	loadsp 24
	im 1
	addsp 4
	loadb
	im 2
	addsp 8
	loadb
	loadsp 4
	im 16
	ashiftleft
	loadsp 4
	im 8
	ashiftleft
	or
	im 3
	addsp 16
	loadb
	loadsp 0
	loadsp 8
	or
	im 8
	ashiftleft
	im 4
	addsp 24
	loadb
	loadsp 4
	or
	storesp 4
	storesp 8
	storesp 12
	storesp 28
	storesp 28
	storesp 16
	storesp 8
	im 8
	storesp 4
	im _Z11simpleReplyj
	call
	im 255
	storesp 4
	im _Z7outbytei
	call
	im 142606340
	storesp 12
.L164:
	loadsp 8
	load
	loadsp 0
	im 1
	lshiftright
	loadsp 0
	im 1
	and
	storesp 4
	storesp 4
	storesp 8
	loadsp 4
	impcrel .L164
	neqbranch
	loadsp 12
	im 65536
	or
	im 142606340
	store
	im 6
	pushspadd
	popsp
	poppc
	.size	_Z16cmd_set_baudratePh, .-_Z16cmd_set_baudratePh
	.section	.text._Z13cmd_waitreadyPh,"ax",@progbits
	.type	_Z13cmd_waitreadyPh, @function
_Z13cmd_waitreadyPh:
	im -2
	pushspadd
	popsp
.L174:
	im _Z15spi_read_statusv
	call
	im _memreg+0
	load
	im _memreg+0
	load
	im 1
	and
	storesp 12
	storesp 12
	loadsp 4
	impcrel .L174
	neqbranch
	im _Z11prepareSendv
	call
	im 131
	storesp 4
	im _Z8sendBytej
	call
	loadsp 8
	storesp 4
	im _Z8sendBytej
	call
	im _Z10finishSendv
	call
	im 4
	pushspadd
	popsp
	poppc
	.size	_Z13cmd_waitreadyPh, .-_Z13cmd_waitreadyPh
	.section	.text._Z11cmd_versionPh,"ax",@progbits
	.type	_Z11cmd_versionPh, @function
_Z11cmd_versionPh:
	im -2
	pushspadd
	popsp
	im 0
	nop
	im milisseconds
	store
	im _Z11prepareSendv
	call
	im 129
	storesp 4
	im _Z8sendBytej
	call
	im vstring
	storesp 12
	im 19
	storesp 8
.L180:
	loadsp 8
	loadsp 0
	im 1
	add
	storesp 16
	loadb
	storesp 4
	im _Z8sendBytej
	call
	im -1
	addsp 8
	storesp 8
	loadsp 4
	im -1
	eq
	not
	im 1
	and
	impcrel .L180
	neqbranch
	im _Z10finishSendv
	call
	im 4
	pushspadd
	popsp
	poppc
	.size	_Z11cmd_versionPh, .-_Z11cmd_versionPh
	.section	.text._Z12cmd_identifyPh,"ax",@progbits
	.type	_Z12cmd_identifyPh, @function
_Z12cmd_identifyPh:
	im -2
	pushspadd
	popsp
	im 0
	nop
	im milisseconds
	store
	im _Z11prepareSendv
	call
	im 130
	storesp 4
	im _Z8sendBytej
	call
	im 167772164
	storesp 8
	im _Z10spi_enablev
	call
	im -1627389952
	nop
	im 167772188
	store
	loadsp 4
	load
	loadsp 8
	storesp 8
	storesp 12
	im _Z11spi_disablePVj
	call
	loadsp 8
	im flash_id
	store
	loadsp 8
	im 16
	lshiftright
	storesp 4
	im _Z8sendBytej
	call
	im flash_id
	load
	im 8
	lshiftright
	storesp 4
	im _Z8sendBytej
	call
	im flash_id
	load
	storesp 4
	im _Z8sendBytej
	call
	im _Z15spi_read_statusv
	call
	im _memreg+0
	load
	storesp 4
	im _Z8sendBytej
	call
	im _Z10finishSendv
	call
	im 4
	pushspadd
	popsp
	poppc
	.size	_Z12cmd_identifyPh, .-_Z12cmd_identifyPh
	.section	.text._Z12cmd_enterpgmPh,"ax",@progbits
	.type	_Z12cmd_enterpgmPh, @function
_Z12cmd_enterpgmPh:
	im 0
	pushspadd
	popsp
	im 1
	nop
	im inprogrammode
	store
	im 0
	nop
	im 159383552
	store
	im 5
	storesp 4
	im _Z11simpleReplyj
	call
	im 2
	pushspadd
	popsp
	poppc
	.size	_Z12cmd_enterpgmPh, .-_Z12cmd_enterpgmPh
	.section	.text._Z12cmd_leavepgmPh,"ax",@progbits
	.type	_Z12cmd_leavepgmPh, @function
_Z12cmd_leavepgmPh:
	im 0
	pushspadd
	popsp
	im 0
	nop
	im inprogrammode
	store
	im _Z11enableTimerv
	call
	im 6
	storesp 4
	im _Z11simpleReplyj
	call
	im 2
	pushspadd
	popsp
	poppc
	.size	_Z12cmd_leavepgmPh, .-_Z12cmd_leavepgmPh
	.section	.text._Z9cmd_startPh,"ax",@progbits
	.globl	_Z9cmd_startPh
	.type	_Z9cmd_startPh, @function
_Z9cmd_startPh:
	im -3
	pushspadd
	popsp
	im 167772164
	storesp 16
	im 10
	storesp 4
	im _Z11simpleReplyj
	call
	im _Z10spi_enablev
	call
	im bdata
	loadsp 16
	storesp 8
	storesp 12
	im _Z15start_read_sizePVj
	call
	loadsp 8
	im _memreg+0
	load
	addsp 0
	addsp 0
	im 393220
	add
	loadsp 4
	loadsp 0
	im 4
	add
	storesp 12
	store
	storesp 8
	im -1342107475
	loadsp 8
	store
	im vstring
	nop
	im 8
	addsp 16
	store
	loadsp 12
	storesp 4
	im _Z11spi_disablePVj
	call
	im _Z5flushv
	call
	im start
	call
	.size	_Z9cmd_startPh, .-_Z9cmd_startPh
	.section	.text.loadsketch,"ax",@progbits
	.globl	loadsketch
	.type	loadsketch, @function
loadsketch:
	im -4
	pushspadd
	popsp
	im 167772164
	loadsp 0
	storesp 8
	storesp 20
	im _Z11spi_disablePVj
	call
	im _Z10spi_enablev
	call
	im 11
	loadsp 20
	store
	loadsp 24
	im 167772180
	store
	im 0
	loadsp 20
	store
	im 4096
	storesp 16
	loadsp 28
	storesp 12
	im 192937984
	storesp 8
	loadsp 16
	storesp 4
	im copy_sketch
	call
	loadsp 16
	storesp 4
	im _Z11spi_disablePVj
	call
	im _Z5flushv
	call
	im start
	call
	.size	loadsketch, .-loadsketch
	.section	.text.setup_uart,"ax",@progbits
	.globl	setup_uart
	.type	setup_uart, @function
setup_uart:
	im 65587
	nop
	im 142606340
	store
	poppc
	.size	setup_uart, .-setup_uart
	.section	.text.main,"ax",@progbits
	.globl	main
	.type	main, @function
main:
	im -85
	pushspadd
	popsp
	im 89
	pushspadd
	load
	storesp 24
	im 0
	nop
	im inprogrammode
	store
	im 0
	nop
	im milisseconds
	store
	im 0
	nop
	im -4224
	addsp 28
	im vstring+5
	loadsp 4
	im 16
	lshiftright
	loadsp 4
	storesp 24
	storesp 24
	storesp 28
	storesp 20
	storesp 28
	loadsp 8
	loadsp 8
	loadsp 0
	im 1
	add
	storesp 16
	storeb
	loadsp 12
	im 8
	lshiftright
	storesp 12
	loadsp 8
	loadsp 8
	storeb
	loadsp 12
	im 2
	addsp 24
	storeb
	loadsp 20
	im 24
	lshiftright
	storesp 8
	loadsp 4
	im 11
	addsp 24
	storeb
	loadsp 20
	im 16
	lshiftright
	storesp 8
	loadsp 4
	im 12
	addsp 24
	storeb
	loadsp 20
	im 8
	lshiftright
	storesp 8
	loadsp 4
	im 13
	addsp 24
	storeb
	loadsp 20
	im 14
	addsp 24
	storeb
	im _zpu_interrupt
	nop
	im ivector
	store
	im 142606340
	storesp 20
	im 65587
	loadsp 20
	store
	im 150994980
	storesp 12
	im -65537
	loadsp 12
	load
	loadsp 0
	loadsp 8
	and
	loadsp 20
	store
	storesp 12
	storesp 16
	im 150994964
	loadsp 0
	load
	loadsp 0
	loadsp 24
	and
	loadsp 8
	store
	storesp 12
	storesp 12
	im 8
	nop
	im 134217732
	store
	im 134217728
	storesp 12
	im 1
	loadsp 12
	store
	im _Z11enableTimerv
	call
	im -31736
	nop
	im 192937988
	store
	im 242
	nop
	im 167772160
	store
	im 167772164
	loadsp 0
	storesp 8
	storesp 8
	im _Z11spi_disablePVj
	call
	im _Z10spi_enablev
	call
	loadsp 4
	storesp 4
	im _Z11spi_disablePVj
	call
	im _Z10spi_enablev
	call
	im 4
	loadsp 8
	store
	loadsp 4
	storesp 4
	im _Z11spi_disablePVj
	call
	loadsp 24
	loadsp 28
	loadsp 24
	loadsp 20
	im 19
	pushspadd
	storesp 68
	storesp 68
	storesp 44
	storesp 44
	storesp 44
	im 192937984
	storesp 48
.L253:
	loadsp 32
	load
	loadsp 0
	im 1
	and
	storesp 4
	storesp 8
	loadsp 4
	impcrel .L247
	neqbranch
	im inprogrammode
	load
	storesp 12
	loadsp 8
	impcrel .L253
	neqbranch
	im milisseconds
	load
	storesp 8
	im 1000
	loadsp 8
	ulessthanorequal
	impcrel .L253
	neqbranch
	loadsp 8
	loadsp 56
	store
	loadsp 8
	im 159383552
	store
	im spi_copy
	call
.L247:
	im 142606336
	load
	storesp 12
	loadsp 36
	im 0
	eq
	impcrel .L227
	neqbranch
	loadsp 8
	im 126
	eq
	not
	im 1
	and
	impcrel .L228
	neqbranch
	loadsp 24
	im 0
	eq
	impcrel .L253
	neqbranch
	im 0
	loadsp 52
	loadsp 32
	storesp 28
	storesp 28
	storesp 40
	im 2
	loadsp 28
	ulessthanorequal
	impcrel .L253
	neqbranch
	im 65535
	loadsp 48
	store
	loadsp 36
	im -2
	addsp 32
	storesp 12
	storesp 12
	loadsp 36
	loadsp 8
	ulessthanorequal
	impcrel .L249
	neqbranch
	im 192937992
	loadsp 8
	storesp 20
	storesp 32
.L235:
	loadsp 20
	addsp 12
	loadsp 0
	loadb
	loadsp 36
	store
	storesp 8
	im 1
	addsp 12
	storesp 12
	loadsp 12
	loadsp 12
	ulessthan
	impcrel .L235
	neqbranch
.L249:
	im -1
	addsp 20
	loadsp 0
	addsp 28
	storesp 16
	loadsp 24
	add
	im -1
	add
	loadsp 0
	loadb
	loadsp 16
	loadb
	loadsp 0
	loadsp 8
	im 8
	ashiftleft
	or
	loadsp 60
	load
	storesp 12
	storesp 4
	storesp 20
	storesp 4
	storesp 8
	loadsp 4
	loadsp 12
	eq
	not
	im 1
	and
	impcrel .L253
	neqbranch
	loadsp 20
	loadb
	storesp 12
	loadsp 8
	im 10
	ulessthan
	impcrel .L253
	neqbranch
	loadsp 8
	addsp 0
	addsp 0
	im handlers-4
	add
	loadsp 24
	storesp 8
	loadsp 0
	load
	storesp 4
	storesp 8
	loadsp 4
	call
	impcrel .L253
	poppcrel
.L228:
	loadsp 8
	im 125
	eq
	not
	im 1
	and
	impcrel .L239
	neqbranch
	im 1
	storesp 44
	impcrel .L253
	poppcrel
.L239:
	loadsp 24
	im 287
	ulessthan
	impcrel .L241
	neqbranch
	loadsp 40
	im 0
	eq
	impcrel .L242
	neqbranch
	im 0
	loadsp 12
	im 32
	xor
	storesp 16
	storesp 44
.L242:
	im 87
	pushspadd
	loadsp 28
	add
	im -288
	add
	storesp 8
	loadsp 8
	loadsp 8
	storeb
	im 1
	addsp 28
	storesp 28
	impcrel .L253
	poppcrel
.L241:
	im 0
	storesp 40
	impcrel .L253
	poppcrel
.L227:
	loadsp 8
	im 126
	eq
	not
	im 1
	and
	impcrel .L253
	neqbranch
	loadsp 36
	storesp 28
	im -1
	loadsp 48
	store
	im 1
	loadsp 28
	storesp 48
	storesp 40
	impcrel .L253
	poppcrel
	.size	main, .-main
	.ident	"GCC: (GNU) 3.4.2"
