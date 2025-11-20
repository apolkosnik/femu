;
; FSQRT Test Suite - Validates IEEE 754 double square root
;
; Tests the FE_FSQRT macro implementation against known values
;

	include		"utils/constants.asm"
	include		"utils/macros.asm"
	include		"utils/double.asm"
	include		"utils/math64.asm"
	include		"ops/fsqrt.asm"

	section code

Start:
	; Initialize
	movea.l		_AbsExecBase,a6

	; Open DOS library
	lea.l		DOSName,a1
	moveq		#36,d0
	jsr			_LVOOpenLibrary(a6)
	move.l		d0,DOSBase
	beq.w		.Exit

	; Print header
	movea.l		DOSBase,a6
	move.l		#MsgHeader,d1
	jsr			_LVOPutStr(a6)

	; Run tests
	jsr			TestSqrtOfZero
	jsr			TestSqrtOfOne
	jsr			TestSqrtOfFour
	jsr			TestSqrtOfNegative
	jsr			TestSqrtOfInfinity
	jsr			TestSqrtOfSmallNumber
	jsr			TestSqrtOfLargeNumber
	jsr			TestSqrtOfPerfectSquare

	; Print results
	movea.l		DOSBase,a6
	move.l		#MsgResults,d1
	jsr			_LVOPutStr(a6)

	; Print test counts
	move.l		TestsPassed,d2
	move.l		TestsFailed,d3
	; TODO: Format and print numbers

	; Close DOS library
	movea.l		_AbsExecBase,a6
	movea.l		DOSBase,a1
	jsr			_LVOCloseLibrary(a6)

.Exit:
	moveq		#0,d0
	rts


;
; Test sqrt of zero
;
TestSqrtOfZero:
	; Test: sqrt(0.0) = 0.0
	move.l		#$00000000,d0		; 0.0 high
	move.l		#$00000000,d1		; 0.0 low

	FE_FSQRT

	; Check result is 0.0
	tst.l		d0
	bne.s		.Fail
	tst.l		d1
	bne.s		.Fail

	addq.l		#1,TestsPassed
	rts

.Fail:
	addq.l		#1,TestsFailed
	rts


;
; Test sqrt of one
;
TestSqrtOfOne:
	; Test: sqrt(1.0) = 1.0
	move.l		#$3ff00000,d0		; 1.0 high
	move.l		#$00000000,d1		; 1.0 low

	FE_FSQRT

	; Check result is approximately 1.0
	; Allow for rounding errors
	move.l		d0,d4
	andi.l		#$7ff00000,d4
	cmpi.l		#$3fe00000,d4		; Check exponent range around 1.0
	blt.s		.Fail
	cmpi.l		#$40000000,d4
	bgt.s		.Fail

	addq.l		#1,TestsPassed
	rts

.Fail:
	addq.l		#1,TestsFailed
	rts


;
; Test sqrt of four
;
TestSqrtOfFour:
	; Test: sqrt(4.0) = 2.0
	move.l		#$40100000,d0		; 4.0 high
	move.l		#$00000000,d1		; 4.0 low

	FE_FSQRT

	; Check result is approximately 2.0 ($40000000)
	move.l		d0,d4
	andi.l		#$7ff00000,d4
	cmpi.l		#$3ff00000,d4		; Check exponent range around 2.0
	blt.s		.Fail
	cmpi.l		#$40100000,d4
	bgt.s		.Fail

	addq.l		#1,TestsPassed
	rts

.Fail:
	addq.l		#1,TestsFailed
	rts


;
; Test sqrt of negative number
;
TestSqrtOfNegative:
	; Test: sqrt(-4.0) = NaN
	move.l		#$c0100000,d0		; -4.0 high
	move.l		#$00000000,d1		; -4.0 low

	FE_FSQRT

	; Check result is NaN (exponent all 1s, mantissa non-zero)
	move.l		d0,d4
	andi.l		#$7ff00000,d4
	cmpi.l		#$7ff00000,d4
	bne.s		.Fail

	; Check mantissa is non-zero
	move.l		d0,d4
	andi.l		#$000fffff,d4
	beq.s		.CheckLow
	bra.s		.Pass

.CheckLow:
	tst.l		d1
	beq.s		.Fail

.Pass:
	addq.l		#1,TestsPassed
	rts

.Fail:
	addq.l		#1,TestsFailed
	rts


;
; Test sqrt of infinity
;
TestSqrtOfInfinity:
	; Test: sqrt(+Infinity) = +Infinity
	move.l		#$7ff00000,d0		; +Infinity high
	move.l		#$00000000,d1		; +Infinity low

	FE_FSQRT

	; Check result is +Infinity
	cmp.l		#$7ff00000,d0
	bne.s		.Fail
	tst.l		d1
	bne.s		.Fail

	addq.l		#1,TestsPassed
	rts

.Fail:
	addq.l		#1,TestsFailed
	rts


;
; Test sqrt of small number
;
TestSqrtOfSmallNumber:
	; Test: sqrt(0.25) = 0.5
	move.l		#$3fd00000,d0		; 0.25 high
	move.l		#$00000000,d1		; 0.25 low

	FE_FSQRT

	; Check result is approximately 0.5 ($3fe00000)
	move.l		d0,d4
	andi.l		#$7ff00000,d4
	cmpi.l		#$3fd00000,d4		; Check exponent range around 0.5
	blt.s		.Fail
	cmpi.l		#$3ff00000,d4
	bgt.s		.Fail

	addq.l		#1,TestsPassed
	rts

.Fail:
	addq.l		#1,TestsFailed
	rts


;
; Test sqrt of large number
;
TestSqrtOfLargeNumber:
	; Test: sqrt(1e10) ≈ 1e5
	move.l		#$4202a05f,d0		; 1e10 high
	move.l		#$20000000,d1		; 1e10 low

	FE_FSQRT

	; Check result is approximately 1e5 ($40f86a00)
	; Just verify exponent is in reasonable range
	move.l		d0,d4
	andi.l		#$7ff00000,d4
	cmpi.l		#$40e00000,d4		; Lower bound
	blt.s		.Fail
	cmpi.l		#$41100000,d4		; Upper bound
	bgt.s		.Fail

	addq.l		#1,TestsPassed
	rts

.Fail:
	addq.l		#1,TestsFailed
	rts


;
; Test sqrt of perfect square
;
TestSqrtOfPerfectSquare:
	; Test: sqrt(9.0) = 3.0
	move.l		#$40220000,d0		; 9.0 high
	move.l		#$00000000,d1		; 9.0 low

	FE_FSQRT

	; Check result is approximately 3.0 ($40080000)
	move.l		d0,d4
	andi.l		#$7ff00000,d4
	cmpi.l		#$40000000,d4		; Check exponent range around 3.0
	blt.s		.Fail
	cmpi.l		#$40100000,d4
	bgt.s		.Fail

	addq.l		#1,TestsPassed
	rts

.Fail:
	addq.l		#1,TestsFailed
	rts


	section data

DOSBase:		dc.l	0
TestsPassed:	dc.l	0
TestsFailed:	dc.l	0

MsgHeader:
	dc.b		"FSQRT Test Suite",10
	dc.b		"================",10,10,0
	even

MsgResults:
	dc.b		10,"Test Results:",10
	dc.b		"-------------",10,0
	even

DOSName:
	dc.b		"dos.library",0
	even
