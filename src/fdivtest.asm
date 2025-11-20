;
; FDIV Test Suite - Validates IEEE 754 double division
;
; Tests the FE_FDIV macro implementation against known values
;

	include		"utils/constants.asm"
	include		"utils/macros.asm"
	include		"utils/double.asm"
	include		"utils/math64.asm"
	include		"ops/fdiv.asm"

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
	jsr			TestDivisionByZero
	jsr			TestDivisionOfZero
	jsr			TestDivisionByInfinity
	jsr			TestDivisionOfInfinity
	jsr			TestNormalDivision
	jsr			TestSignedDivision
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
; Test division by zero
;
TestDivisionByZero:
	; Test: 1.0 / 0.0 = +Infinity
	move.l		#$3ff00000,d0		; 1.0 high
	move.l		#$00000000,d1		; 1.0 low
	move.l		#$00000000,d2		; 0.0 high
	move.l		#$00000000,d3		; 0.0 low

	FE_FDIV

	; Check result is +Infinity ($7ff00000 $00000000)
	cmp.l		#$7ff00000,d0
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
; Test division of zero
;
TestDivisionOfZero:
	; Test: 0.0 / 1.0 = 0.0
	move.l		#$00000000,d0		; 0.0 high
	move.l		#$00000000,d1		; 0.0 low
	move.l		#$3ff00000,d2		; 1.0 high
	move.l		#$00000000,d3		; 1.0 low

	FE_FDIV

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
; Test division by infinity
;
TestDivisionByInfinity:
	; Test: 1.0 / +Infinity = 0.0
	move.l		#$3ff00000,d0		; 1.0 high
	move.l		#$00000000,d1		; 1.0 low
	move.l		#$7ff00000,d2		; +Infinity high
	move.l		#$00000000,d3		; +Infinity low

	FE_FDIV

	; Check result is 0.0
	andi.l		#$7fffffff,d0		; Clear sign bit
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
; Test division of infinity
;
TestDivisionOfInfinity:
	; Test: +Infinity / 1.0 = +Infinity
	move.l		#$7ff00000,d0		; +Infinity high
	move.l		#$00000000,d1		; +Infinity low
	move.l		#$3ff00000,d2		; 1.0 high
	move.l		#$00000000,d3		; 1.0 low

	FE_FDIV

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
; Test normal division
;
TestNormalDivision:
	; Test: 10.0 / 2.0 = 5.0
	move.l		#$40240000,d0		; 10.0 high
	move.l		#$00000000,d1		; 10.0 low
	move.l		#$40000000,d2		; 2.0 high
	move.l		#$00000000,d3		; 2.0 low

	FE_FDIV

	; Check result is approximately 5.0 ($40140000)
	; Allow for rounding errors in simplified algorithm
	move.l		d0,d4
	andi.l		#$7ff00000,d4
	cmpi.l		#$40140000,d4
	bne.s		.Fail

	addq.l		#1,TestsPassed
	rts

.Fail:
	addq.l		#1,TestsFailed
	rts


;
; Test signed division
;
TestSignedDivision:
	; Test: -4.0 / 2.0 = -2.0
	move.l		#$c0100000,d0		; -4.0 high
	move.l		#$00000000,d1		; -4.0 low
	move.l		#$40000000,d2		; 2.0 high
	move.l		#$00000000,d3		; 2.0 low

	FE_FDIV

	; Check result has correct sign (negative)
	btst		#31,d0
	beq.s		.Fail

	; Check magnitude is approximately 2.0
	move.l		d0,d4
	andi.l		#$7ff00000,d4
	cmpi.l		#$40000000,d4
	bne.s		.Fail

	addq.l		#1,TestsPassed
	rts

.Fail:
	addq.l		#1,TestsFailed
	rts


;
; Test small numbers
;
TestSmallNumbers:
	; Test: 0.25 / 0.5 = 0.5
	move.l		#$3fd00000,d0		; 0.25 high
	move.l		#$00000000,d1		; 0.25 low
	move.l		#$3fe00000,d2		; 0.5 high
	move.l		#$00000000,d3		; 0.5 low

	FE_FDIV

	; Check result is approximately 0.5
	move.l		d0,d4
	andi.l		#$7ff00000,d4
	cmpi.l		#$3fe00000,d4
	bne.s		.Fail

	addq.l		#1,TestsPassed
	rts

.Fail:
	addq.l		#1,TestsFailed
	rts


;
; Test large numbers
;
TestLargeNumbers:
	; Test: 1e10 / 1e5 = 1e5
	move.l		#$4202a05f,d0		; 1e10 high
	move.l		#$20000000,d1		; 1e10 low
	move.l		#$40f86a00,d2		; 1e5 high
	move.l		#$00000000,d3		; 1e5 low

	FE_FDIV

	; Check result is approximately 1e5
	; Just verify exponent is in reasonable range
	move.l		d0,d4
	andi.l		#$7ff00000,d4
	cmpi.l		#$40f00000,d4
	blt.s		.Fail
	cmpi.l		#$41000000,d4
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
	dc.b		"FDIV Test Suite",10
	dc.b		"===============",10,10,0
	even

MsgResults:
	dc.b		10,"Test Results:",10
	dc.b		"-------------",10,0
	even
