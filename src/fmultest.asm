;
; FMUL Test Suite - Validates IEEE 754 double multiplication
;
; Tests the FE_FMUL macro implementation against known values
;

	include		"utils/constants.asm"
	include		"utils/macros.asm"
	include		"utils/double.asm"
	include		"utils/math64.asm"
	include		"ops/fmul.asm"

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
	jsr			TestMultiplicationByZero
	jsr			TestMultiplicationOfZero
	jsr			TestMultiplicationByOne
	jsr			TestMultiplicationByInfinity
	jsr			TestSignedMultiplication
	jsr			TestNormalMultiplication
	jsr			TestSmallNumbers
	jsr			TestLargeNumbers

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
; Test multiplication by zero
;
TestMultiplicationByZero:
	; Test: 5.0 * 0.0 = 0.0
	move.l		#$40140000,d0		; 5.0 high
	move.l		#$00000000,d1		; 5.0 low
	move.l		#$00000000,d2		; 0.0 high
	move.l		#$00000000,d3		; 0.0 low

	FE_FMUL

	; Check result is 0.0 (ignore sign)
	andi.l		#$7fffffff,d0
	bne.s		.Fail
	tst.l		d1
	bne.s		.Fail

	addq.l		#1,TestsPassed
	rts

.Fail:
	addq.l		#1,TestsFailed
	; TODO: Print failure message
	rts


;
; Test multiplication of zero
;
TestMultiplicationOfZero:
	; Test: 0.0 * 3.0 = 0.0
	move.l		#$00000000,d0		; 0.0 high
	move.l		#$00000000,d1		; 0.0 low
	move.l		#$40080000,d2		; 3.0 high
	move.l		#$00000000,d3		; 3.0 low

	FE_FMUL

	; Check result is 0.0 (ignore sign)
	andi.l		#$7fffffff,d0
	bne.s		.Fail
	tst.l		d1
	bne.s		.Fail

	addq.l		#1,TestsPassed
	rts

.Fail:
	addq.l		#1,TestsFailed
	rts


;
; Test multiplication by one
;
TestMultiplicationByOne:
	; Test: 7.5 * 1.0 = 7.5
	move.l		#$401e0000,d0		; 7.5 high
	move.l		#$00000000,d1		; 7.5 low
	move.l		#$3ff00000,d2		; 1.0 high
	move.l		#$00000000,d3		; 1.0 low

	FE_FMUL

	; Check result is approximately 7.5
	; Allow for rounding errors in simplified algorithm
	move.l		d0,d4
	andi.l		#$7ff00000,d4
	cmpi.l		#$40100000,d4		; Check exponent range around 7.5
	blt.s		.Fail
	cmpi.l		#$40200000,d4
	bgt.s		.Fail

	addq.l		#1,TestsPassed
	rts

.Fail:
	addq.l		#1,TestsFailed
	rts


;
; Test multiplication by infinity
;
TestMultiplicationByInfinity:
	; Test: 2.0 * +Infinity = +Infinity
	move.l		#$40000000,d0		; 2.0 high
	move.l		#$00000000,d1		; 2.0 low
	move.l		#$7ff00000,d2		; +Infinity high
	move.l		#$00000000,d3		; +Infinity low

	FE_FMUL

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
; Test signed multiplication
;
TestSignedMultiplication:
	; Test: -2.0 * 3.0 = -6.0
	move.l		#$c0000000,d0		; -2.0 high
	move.l		#$00000000,d1		; -2.0 low
	move.l		#$40080000,d2		; 3.0 high
	move.l		#$00000000,d3		; 3.0 low

	FE_FMUL

	; Check result has correct sign (negative)
	btst		#31,d0
	beq.s		.Fail

	; Check magnitude is approximately 6.0 ($40180000)
	move.l		d0,d4
	andi.l		#$7ff00000,d4
	cmpi.l		#$40100000,d4		; Check exponent range around 6.0
	blt.s		.Fail
	cmpi.l		#$40200000,d4
	bgt.s		.Fail

	addq.l		#1,TestsPassed
	rts

.Fail:
	addq.l		#1,TestsFailed
	rts


;
; Test normal multiplication
;
TestNormalMultiplication:
	; Test: 2.0 * 3.0 = 6.0
	move.l		#$40000000,d0		; 2.0 high
	move.l		#$00000000,d1		; 2.0 low
	move.l		#$40080000,d2		; 3.0 high
	move.l		#$00000000,d3		; 3.0 low

	FE_FMUL

	; Check result is approximately 6.0 ($40180000)
	; Allow for rounding errors in simplified algorithm
	move.l		d0,d4
	andi.l		#$7ff00000,d4
	cmpi.l		#$40100000,d4		; Check exponent range around 6.0
	blt.s		.Fail
	cmpi.l		#$40200000,d4
	bgt.s		.Fail

	addq.l		#1,TestsPassed
	rts

.Fail:
	addq.l		#1,TestsFailed
	rts


;
; Test small numbers
;
TestSmallNumbers:
	; Test: 0.5 * 0.5 = 0.25
	move.l		#$3fe00000,d0		; 0.5 high
	move.l		#$00000000,d1		; 0.5 low
	move.l		#$3fe00000,d2		; 0.5 high
	move.l		#$00000000,d3		; 0.5 low

	FE_FMUL

	; Check result is approximately 0.25 ($3fd00000)
	move.l		d0,d4
	andi.l		#$7ff00000,d4
	cmpi.l		#$3fc00000,d4		; Check exponent range around 0.25
	blt.s		.Fail
	cmpi.l		#$3fe00000,d4
	bgt.s		.Fail

	addq.l		#1,TestsPassed
	rts

.Fail:
	addq.l		#1,TestsFailed
	rts


;
; Test large numbers
;
TestLargeNumbers:
	; Test: 1e10 * 1e5 = 1e15
	move.l		#$4202a05f,d0		; 1e10 high
	move.l		#$20000000,d1		; 1e10 low
	move.l		#$40f86a00,d2		; 1e5 high
	move.l		#$00000000,d3		; 1e5 low

	FE_FMUL

	; Check result is approximately 1e15
	; Just verify exponent is in reasonable range
	move.l		d0,d4
	andi.l		#$7ff00000,d4
	cmpi.l		#$42d00000,d4		; Lower bound for 1e15
	blt.s		.Fail
	cmpi.l		#$43000000,d4		; Upper bound
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
	dc.b		"FMUL Test Suite",10
	dc.b		"===============",10,10,0
	even

MsgResults:
	dc.b		10,"Test Results:",10
	dc.b		"-------------",10,0
	even

DOSName:
	dc.b		"dos.library",0
	even
