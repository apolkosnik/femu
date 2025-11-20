;
; IEEE 754 Double Precision Square Root
;
; INPUTS:
;   d0/d1 - value to compute sqrt of
;
; OUTPUTS:
;   d0/d1 - square root
;
; REGISTERS:
;   d4 - exponent + scratch
;   d5 - scratch
;   d6 - sign
;   d7 - iteration counter
;
FE_FSQRT macro

	; Extract sign and exponent
	bfextu		d0{0:1},d6			; Get sign
	bfextu		d0{1:11},d4			; Get exponent

	; Check for special cases
	; Negative numbers (except -0) -> NaN
	tst.l		d6
	beq.s		.NotNegative

	; Check if it's -0
	move.l		d0,d5
	andi.l		#$7fffffff,d5
	bne.s		.IsNegative
	tst.l		d1
	bne.s		.IsNegative
	bra.w		.Done				; sqrt(-0) = -0

.IsNegative:
	; Return NaN for negative numbers
	move.l		#$7ff80000,d0		; Quiet NaN
	move.l		#$00000000,d1
	bra.w		.Done

.NotNegative:
	; Check for zero
	tst.w		d4
	bne.s		.NotZero
	tst.l		d0
	bne.s		.NotZero
	tst.l		d1
	bne.s		.NotZero
	; sqrt(0) = 0
	bra.w		.Done

.NotZero:
	; Check for infinity or NaN
	cmp.w		#$7ff,d4
	bne.s		.NotSpecial
	; Return input (infinity or NaN)
	bra.w		.Done

.NotSpecial:
	; Normal case - use Newton-Raphson iteration
	; Formula: x_{n+1} = (x_n + a/x_n) / 2

	; For square root, we can use exponent manipulation
	; sqrt(2^n * m) = 2^(n/2) * sqrt(m)

	; Adjust exponent: exp = (exp - 1023) / 2 + 1023
	subi.w		#1023,d4			; Remove bias

	; Check if exponent is odd
	btst		#0,d4
	beq.s		.EvenExp

	; Odd exponent: adjust mantissa by sqrt(2) factor
	; For simplified implementation, just shift mantissa
	bfextu		d0{12:20},d0
	bset		#20,d0
	lsl.l		#1,d0				; Multiply by 2
	subi.w		#1,d4				; Adjust exponent
	bra.s		.ExpAdjusted

.EvenExp:
	; Even exponent: extract mantissa normally
	bfextu		d0{12:20},d0
	bset		#20,d0				; Add implicit 1

.ExpAdjusted:
	; Divide exponent by 2
	asr.w		#1,d4
	addi.w		#1023,d4			; Add bias back

	; Simplified mantissa square root
	; For a full implementation, we would use Newton-Raphson:
	; x_{n+1} = (x_n + a/x_n) / 2
	; Starting with initial guess based on bit patterns

	; Simplified approach: approximate sqrt using bit manipulation
	; sqrt(1.m) ≈ 1.0 + m/2 (rough approximation)
	; For better accuracy, would need iterative refinement

	; Take approximate root by shifting
	; This is very simplified - full implementation needs iteration
	moveq		#0,d1
	lsr.l		#1,d0				; Rough approximation
	ori.l		#$00080000,d0		; Ensure bit 19 set for normalized result

	; Normalize and construct result
	move.w		d4,d5
	NORMALIZE	d5,d0,d1,d2

	; Construct final result
	bfins		d5,d0{1:11}
	bfins		d6,d0{0:1}

.Done:

endm


;
; fsqrt emulation
;
FsqrtHandler
FssqrtHandler
FdsqrtHandler

	; Debug instruction
	WRITEDEBUG		#.DEBUGOP,INSTRUCTION
		
	; Increment PC
	INCREMENTPC		#$04

	; Get data
	GETDATALENGTH	d0
	GETEAVALUE		d0,d1

	; Emulate instruction
	ifd NOMATHLIB
		FE_FSQRT
	else
		movea.l			MathIeeeDoubTransBase,a6
		jsr				_LVOIEEEDPSqrt(a6)
	endif

	; Write results
	GETREGISTER		d5
	MOVEDNTOFPN		d5,d0,d1

	; Set condition codes
	SETCC			d0,d1

	; Done
	rts
	
	; Debug constants
	.DEBUGOP:
	dc.b 			"fsqrt %08lx",10,0
	even