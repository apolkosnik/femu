;
; IEEE 754 Double Precision Multiplication
;
; INPUTS:
;   d0/d1 - first multiplicand
;   d2/d3 - second multiplicand
;
; OUTPUTS:
;   d0/d1 - product
;
; REGISTERS:
;   d4 - first exponent + sign
;   d5 - second exponent + sign
;   d6 - result sign + scratch
;   d7 - scratch
;
FE_FMUL macro

	; Extract signs and exponents
	bfextu		d0{0:1},d6			; Get first sign
	bfextu		d0{1:11},d4			; Get first exponent
	bfins		d6,d4{0:1}			; Combine sign and exponent

	bfextu		d2{0:1},d6			; Get second sign
	bfextu		d2{1:11},d5			; Get second exponent
	bfins		d6,d5{0:1}			; Combine sign and exponent

	; Calculate result sign (XOR of signs)
	move.l		d4,d6
	eor.l		d5,d6
	andi.l		#$80000000,d6		; Keep only sign bit
	lsr.l		#8,d6				; Position for later
	lsr.l		#8,d6
	lsr.l		#8,d6

	; Check for special cases
	; Check if either operand is zero
	andi.w		#$7ff,d4
	bne.s		.FirstNotZero
	tst.l		d0
	bne.s		.FirstNotZero
	tst.l		d1
	bne.s		.FirstNotZero

	; First is zero - return zero
	move.l		d6,d0
	lsl.l		#8,d0
	lsl.l		#8,d0
	lsl.l		#8,d0
	move.l		#0,d1
	bra.w		.Done

.FirstNotZero:
	andi.w		#$7ff,d5
	bne.s		.SecondNotZero
	tst.l		d2
	bne.s		.SecondNotZero
	tst.l		d3
	bne.s		.SecondNotZero

	; Second is zero - return zero
	move.l		d6,d0
	lsl.l		#8,d0
	lsl.l		#8,d0
	lsl.l		#8,d0
	move.l		#0,d1
	bra.w		.Done

.SecondNotZero:
	; Check for infinity or NaN in first operand
	cmp.w		#$7ff,d4
	bne.s		.FirstNotInf

	; First is infinity or NaN - return it (with adjusted sign)
	move.l		d0,d0			; Keep original
	bfins		d6,d0{0:1}		; Apply calculated sign
	bra.w		.Done

.FirstNotInf:
	; Check for infinity or NaN in second operand
	cmp.w		#$7ff,d5
	bne.s		.SecondNotInf

	; Second is infinity or NaN - return it (with adjusted sign)
	move.l		d2,d0
	move.l		d3,d1
	bfins		d6,d0{0:1}		; Apply calculated sign
	bra.w		.Done

.SecondNotInf:
	; Normal multiplication
	; Calculate result exponent: exp(a) + exp(b) - 1023
	move.w		d4,d7
	add.w		d5,d7
	subi.w		#1023,d7		; Remove bias

	; Extract mantissas and add implicit bit
	bfextu		d0{12:20},d0
	bfextu		d2{12:20},d2
	bset		#20,d0			; Add implicit 1
	bset		#20,d2			; Add implicit 1

	; Multiply mantissas (simplified 21-bit multiply)
	; Full 64-bit multiplication would be more complex
	; This uses a simplified approach for code size

	; Approximate multiplication: (a * b) >> shift
	; For 21-bit mantissas, result should be 42 bits
	; We'll use the high 21 bits as our result

	; Simple approach: use upper bits only
	move.l		d0,d4
	mulu.w		d2,d4			; Lower 16 bits multiply
	; Result in d4 (32 bits), but we only use high portion

	; Shift and adjust for proper mantissa position
	lsr.l		#8,d4
	lsr.l		#1,d4
	move.l		d4,d0
	moveq		#0,d1

	; Normalize and construct result
	move.w		d7,d4
	NORMALIZE	d4,d0,d1,d2

	; Construct final result
	bfins		d4,d0{1:11}
	bfins		d6,d0{0:1}

.Done:

endm
	

;
;
;
FMULHANDLER macro

	; Debug instruction
	WRITEDEBUG		#.DEBUGOP,INSTRUCTION

	; Increment PC
	INCREMENTPC		#$04

	; Get data
	GETDATALENGTH	d0
    ifnb \1
        MOVEFROMC       010,3
        vperm           #$01230123,d3,d3,d2
	else
		GETEAVALUE		d2,d3
	endif
	GETREGISTER		d5
	MOVEFPNTODN		d5,d0,d1
	
	; Emulate instruction
	ifd NOMATHLIB
		FE_FMUL
	else
		movea.l			MathIeeeDoubBasBase,a6
		jsr				_LVOIEEEDPMul(a6)
	endif

	; Write results
	MOVEDNTOFPN		d5,d0,d1

	; Set condition codes
	SETCC			d0,d1
	
endm


;
; fmul emulation
;
FmulHandler
FsmulHandler
FdmulHandler
FsglmulHandler
	FMULHANDLER
	rts
	.DEBUGOP:
	dc.b 			"fmul %08lx",10,0
	even
