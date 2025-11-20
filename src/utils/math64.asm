;
; Performs 64 bit add.
; 
; INPUTS
;	\1 -- High bits.
;	\2 -- Low bits.
;	\3 -- High bits.
;	\4 -- Low bits.
;
; RESULT
;	\1 -- High bits.
;	\2 -- Low bits.
;
ADD64 macro
	add.l			\2,\4
	addx.l			\1,\3
endm


;
; Performs 64 bit sub.
; 
; INPUTS
;	\1 -- High bits.
;	\2 -- Low bits.
;	\3 -- High bits.
;	\4 -- Low bits.
;
; RESULT
;	\1 -- High bits.
;	\2 -- Low bits.
;
SUB64 macro
	sub.l			\2,\4
	subx.l			\1,\3
endm


;
; Performs 64 bit neg.
; 
; INPUTS
;	\1 -- High bits.
;	\2 -- Low bits.
;
; RESULT
;	\1 -- High bits.
;	\2 -- Low bits.
;
NEG64 macro
	neg.l			\2
	negx.l			\1
endm


;
; Performs 64 bit abs.
; 
; INPUTS
;	\1 -- High bits.
;	\2 -- Low bits.
;
; RESULT
;	\1 -- High bits.
;	\2 -- Low bits.
;
ABS64 macro

	;TODO: d6 stuff is WIP, required for FE_FADD implementation, but should not be here!
	moveq			 #0,d6
	
	btst			#31,\1
	beq.s			.\@Ok
	NEG64			\1,\2
	
	moveq			 #1,d6
	
	.\@Ok:
endm


;
; Performs 64 bit lsl. 
; 
; INPUTS
;	\1 -- Shift bits.
;	\2 -- High bits.
;	\3 -- Low bits.
;
; RESULT
;	\1 -- High bits.
;	\2 -- Low bits.
;
; TODO: use LSL.Q for 080v3
;
LSL64 macro

	cmp.b		#32,\1
	blt.s		.\@ShiftLess
	
	.\@ShiftMore:
	move.l		\3,\2
	move.l		#0,\3
	subi.l		#32,\1
	lsl.l		\1,\2
	addi.l		#32,\1
	bra.s		.\@ShiftOk
	
	.\@ShiftLess:
	LSL64L		\1,\2,\3
	
	.\@ShiftOk:

endm


;
; Performs 64 bit lsl. 
; Shifts 32 bits at max. 
; 
; INPUTS
;	\1 -- Shift bits.
;	\2 -- High bits.
;	\3 -- Low bits.
;
; RESULT
;	\1 -- High bits.
;	\2 -- Low bits.
;
; TODO: use LSL.Q for 080v3
; 	19:01 < BigGun> LSL.Q
; 	19:01 < BigGun> example : LSL.Q D0,D1,D2
; 	19:01 < BigGun> shifts D1, (all 64bit)
; 	19:02 < BigGun> by count in D0
; 	19:02 < BigGun> stores result in D2
; 	19:02 < BigGun> AMMX ID = $38
;
LSL64L macro
	rol.l		\1,\3
	bfins		\3,\2{0:\1}
	rol.l		\1,\2
	lsr.l		\1,\3
	lsl.l		\1,\3
endm


;
; Performs 64 bit lsr. 
; 
; INPUTS
;	\1 -- Shift bits.
;	\2 -- High bits.
;	\3 -- Low bits.
;
; RESULT
;	\1 -- High bits.
;	\2 -- Low bits.
;
; TODO: use LSL.Q for 080v3
;
LSR64 macro

	cmp.b		#32,\1
	blt.s		.\@ShiftLess
	
	.\@ShiftMore:
	move.l		\2,\3
	move.l		#0,\2
	subi.l		#32,\1
	lsr.l		\1,\3
	addi.l		#32,\1
	bra.s		.\@ShiftOk
	
	.\@ShiftLess:
	LSR64L		\1,\2,\3
	
	.\@ShiftOk:

endm


;
; Performs 64 bit lsr. 
; Shifts 32 bits at max.
; 
; INPUTS
;	\1 -- Shift bits.
;	\2 -- High bits.
;	\3 -- Low bits.
;
; RESULT
;	\1 -- High bits.
;	\2 -- Low bits.
;
; TODO: use LSL.Q for 080v3
;
LSR64L macro
	lsr.l		\1,\3
	bfins		\2,\3{0:\1}
	lsr.l		\1,\2
endm


;
; Compares two 64-bit values
;
; INPUTS
;	\1 -- High bits of first value
;	\2 -- Low bits of first value
;	\3 -- High bits of second value
;	\4 -- Low bits of second value
;
; RESULT
;	Condition codes set (EQ, GT, LT, etc.)
;
CMP64 macro
	cmp.l		\3,\1
	bne.s		.\@Done
	cmp.l		\4,\2
.\@Done:
endm


;
; Multiplies two 32-bit values to produce 64-bit result
; Uses shift-and-add algorithm
;
; INPUTS
;	\1 -- First 32-bit multiplicand
;	\2 -- Second 32-bit multiplicand
;
; RESULT
;	\3 -- High 32 bits of result
;	\4 -- Low 32 bits of result
;
; SCRATCH
;	Uses \5 as scratch register if provided
;
; Note: Simplified implementation for code size
; Full precision multiply would be more complex
;
MUL32TO64 macro
	; Zero result
	moveq		#0,\3
	move.l		\1,\4

	; Check for zero
	tst.l		\2
	beq.s		.\@Done

	; Simple multiply loop (optimize for common case)
	; For production, use hardware multiply or lookup tables
	move.l		\2,d7

.\@Loop:
	; Shift and add algorithm
	lsr.l		#1,d7
	bcc.s		.\@NoAdd
	add.l		\1,\4
	addx.l		#0,\3
.\@NoAdd:
	add.l		\1,\1		; Shift multiplicand left
	tst.l		d7
	bne.s		.\@Loop

.\@Done:
endm
