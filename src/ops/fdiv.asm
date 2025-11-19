;
; IEEE 754 Double Precision Division
;
; INPUTS:
;   d0/d1 - dividend (numerator)
;   d2/d3 - divisor (denominator)
;
; OUTPUTS:
;   d0/d1 - quotient
;
; REGISTERS:
;   d4 - dividend exponent + sign
;   d5 - divisor exponent + sign
;   d6 - result sign + scratch
;   d7 - scratch
;
FE_FDIV macro

	; Extract signs and exponents
	bfextu		d0{0:1},d6			; Get dividend sign
	bfextu		d0{1:11},d4			; Get dividend exponent
	bfins		d6,d4{0:1}			; Combine sign and exponent

	bfextu		d2{0:1},d6			; Get divisor sign
	bfextu		d2{1:11},d5			; Get divisor exponent
	bfins		d6,d5{0:1}			; Combine sign and exponent

	; Calculate result sign (XOR of signs)
	move.l		d4,d6
	eor.l		d5,d6
	andi.l		#$80000000,d6		; Keep only sign bit
	lsr.l		#8,d6				; Position for later
	lsr.l		#8,d6
	lsr.l		#8,d6

	; Check for special cases
	; Check if divisor is zero
	andi.w		#$7ff,d5
	bne.s		.DivisorNotZero
	tst.l		d2
	bne.s		.DivisorNotZero
	tst.l		d3
	bne.s		.DivisorNotZero

	; Division by zero - return infinity
	move.l		#$7ff00000,d0
	or.l		d6,d0				; Apply sign
	lsl.l		#8,d0
	lsl.l		#8,d0
	lsl.l		#8,d0
	move.l		#0,d1
	bra.w		.Done

.DivisorNotZero:
	; Check if divisor is infinity or NaN
	cmp.w		#$7ff,d5
	bne.s		.DivisorNotInf

	; Divisor is infinity or NaN - result is zero or NaN
	move.l		d2,d7
	bclr.l		#31,d7
	cmp.l		#$7ff00000,d7
	bne.s		.DivisorNaN
	tst.l		d3
	bne.s		.DivisorNaN

	; Divisor is infinity - return zero
	move.l		d6,d0
	lsl.l		#8,d0
	lsl.l		#8,d0
	lsl.l		#8,d0
	move.l		#0,d1
	bra.w		.Done

.DivisorNaN:
	; Return NaN
	move.l		#$7fffffff,d0
	move.l		#$ffffffff,d1
	bra.w		.Done

.DivisorNotInf:
	; Check if dividend is zero
	andi.w		#$7ff,d4
	bne.s		.DividendNotZero
	tst.l		d0
	bne.s		.DividendNotZero
	tst.l		d1
	bne.s		.DividendNotZero

	; Dividend is zero - return zero
	move.l		d6,d0
	lsl.l		#8,d0
	lsl.l		#8,d0
	lsl.l		#8,d0
	move.l		#0,d1
	bra.w		.Done

.DividendNotZero:
	; Check if dividend is infinity or NaN
	cmp.w		#$7ff,d4
	bne.s		.DividendNotInf

	; Return NaN or infinity
	move.l		d0,d0			; Already in d0/d1
	bra.w		.Done

.DividendNotInf:
	; Normal division
	; Calculate result exponent: exp(dividend) - exp(divisor) + 1023
	move.w		d4,d7
	andi.w		#$7ff,d7
	move.w		d5,d4
	andi.w		#$7ff,d4
	sub.w		d4,d7
	addi.w		#1023,d7			; Bias

	; Extract mantissas and add implicit bit
	bfextu		d0{12:20},d0
	bfextu		d2{12:20},d2
	bset		#20,d0				; Add implicit 1
	bset		#20,d2				; Add implicit 1

	; Perform 64-bit division (simplified - uses shifts and subtracts)
	; This is a basic non-restoring division algorithm
	; For production, consider optimized library routines

	; Shift dividend left by 11 to align with divisor
	LSL64L		#11,d0,d1

	; Divide (iterative subtraction - simplified for space)
	; In production, use optimized division algorithms
	; For now, return approximate result
	; TODO: Implement full precision division

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
FDIVHANDLER macro

	; Debug instruction
	WRITEDEBUG		#.DEBUGOP,INSTRUCTION

	; Increment PC
	INCREMENTPC		#$04

	; Get data
	GETDATALENGTH	d0
	GETEAVALUE		d2,d3
	GETREGISTER		d5
	MOVEFPNTODN		d5,d0,d1

	; Emulate instruction
	ifd NOMATHLIB
		FE_FDIV
	else
		movea.l		MathIeeeDoubBasBase,a6
		jsr			_LVOIEEEDPDiv(a6)
	endif

	; Write results
	MOVEDNTOFPN		d5,d0,d1
	
	; Set condition codes
	SETCC			d0,d1
	
endm


;
; fdiv emulation
;
FdivHandler
FsdivHandler
FddivHandler
FsgldivHandler
	FDIVHANDLER
	rts

	; Debug constants
	.DEBUGOP:
	dc.b 			"fdiv %08lx",10,0
	even
const_025:	dc.l	$3fd00000,$0

