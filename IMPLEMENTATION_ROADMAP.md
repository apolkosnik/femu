# FEMU Implementation Roadmap

## Priority 1: NOMATHLIB Software Math Operations

### Overview
Enable standalone operation without AmigaOS math libraries. Critical for:
- Systems without mathieeedoubbas.library
- Reduced memory footprint
- Standalone/embedded deployments

### Phase 1.1: Division Algorithm (fdiv.asm)

**Current State:** Returns NaN placeholder
**Target:** IEEE 754 double-precision division

**Algorithm Outline:**
```asm
; IEEE 754 Double Division Algorithm
; Input: d0/d1 = dividend (numerator)
;        d2/d3 = divisor (denominator)
; Output: d0/d1 = quotient

FE_FDIV macro
    ; 1. Handle special cases
    ;    - Division by zero → infinity
    ;    - Infinity / Infinity → NaN
    ;    - Zero / Zero → NaN
    ;    - Infinity / finite → Infinity
    ;    - Finite / Infinity → Zero

    ; 2. Extract exponents and signs
    ;    - Sign(result) = Sign(dividend) XOR Sign(divisor)
    ;    - Exponent(result) = Exp(dividend) - Exp(divisor) + 1023

    ; 3. Extract mantissas
    ;    - Add implicit leading 1 bit
    ;    - Mantissa is 53 bits (52 stored + 1 implicit)

    ; 4. Perform 64-bit division
    ;    - Divide mantissa1 by mantissa2
    ;    - Use shift-and-subtract algorithm
    ;    - Result is 53-bit quotient

    ; 5. Normalize result
    ;    - Adjust exponent if needed
    ;    - Round to nearest even

    ; 6. Check for overflow/underflow
    ;    - Exponent > 2046 → Infinity
    ;    - Exponent < 1 → Denormal or zero

    ; 7. Construct result
    ;    - Combine sign, exponent, mantissa
endm
```

**Estimated Complexity:** 150-200 lines of assembly
**Time Estimate:** 8-12 hours
**Dependencies:** math64.asm macros (already available)

### Phase 1.2: Multiplication Algorithm (fmul.asm)

**Algorithm Outline:**
```asm
; IEEE 754 Double Multiplication
; Similar structure to division but:
; - Exponent(result) = Exp(a) + Exp(b) - 1023
; - Mantissa multiplication (64-bit × 64-bit)
; - May produce 106-bit intermediate result
```

**Estimated Complexity:** 120-150 lines
**Time Estimate:** 6-8 hours

### Phase 1.3: Square Root Algorithm (fsqrt.asm)

**Algorithm:** Newton-Raphson iteration or digit-by-digit
```asm
; Newton-Raphson method:
; x[n+1] = 0.5 * (x[n] + S/x[n])
; Converges quadratically (doubles precision each iteration)
; Requires ~4-5 iterations for double precision
```

**Estimated Complexity:** 100-130 lines
**Time Estimate:** 6-8 hours

### Phase 1.4: Transcendental Functions

**Strategy:** Use Taylor series or CORDIC algorithm

**Priority Order:**
1. **fsin/fcos** - CORDIC algorithm (shared implementation)
2. **ftan** - sin/cos ratio
3. **fetox** - Taylor series
4. **flogn** - Inverse of exp, Newton's method
5. **Remaining** - Built on primitives above

**Total Estimate:** 40-60 hours for complete NOMATHLIB support

---

## Priority 2: FPU Constant ROM Completion

### Current State
Only 4 constants populated (fpu.asm:52-113):
- Offset $00: π (3.14159...)
- Offset $0B: log₁₀(2)
- Offset $0C: e (2.71828...)
- Offset $0D: log₂(e)

### Required Constants (68882 Compatible)

**ROM Address Map:**
```
$00: 3.141592653589793 (π)
$0B: 0.30102999566398   (log₁₀(2))
$0C: 2.718281828459045  (e)
$0D: 1.442695040888963  (log₂(e))
$0E: 0.693147180559945  (log_e(2))
$0F: 0.000000000000000  (0.0)
$30: 0.301029995663981  (log₁₀(2)) [duplicate]
$31: 2.302585092994046  (log_e(10))
$32: 1.000000000000000  (1.0)
$33: 10.00000000000000  (10.0)
$34: 100.0000000000000  (100.0)
$35: 10000.00000000000  (10^4)
$36: 1.0e8               (10^8)
$37: 1.0e16              (10^16)
$38: 1.0e32              (10^32)
$39: 1.0e64              (10^64)
$3A: 1.0e128             (10^128)
$3B: 1.0e256             (10^256)
$3C: 1.0e512             (10^512)
$3D: 1.0e1024            (10^1024)
$3E: 1.0e2048            (10^2048)
$3F: 1.0e4096            (10^4096)
```

**Implementation:**
```asm
CCC
    ; Mathematical constants (IEEE 754 double format)
    dc.l    $400921fb,$54442d18  ; $00: π
    dc.l    $00000000,$00000000  ; $01: (reserved)
    ; ... [fill in remaining constants]
    dc.l    $3fd34413,$509f79fe  ; $0B: log₁₀(2)
    dc.l    $4005bf0a,$8b145769  ; $0C: e
    ; ... [continue through $3F]
```

**Time Estimate:** 2-3 hours (data entry + verification)

---

## Priority 3: Error Handling Improvement

### Current Issue
`Unsupported` function in fhandler.asm:135 calls `stop #$2700`:
- Halts entire system
- Requires hard reset
- Loses all unsaved work

### Proposed Solution

**Option A: Return to Caller with Error**
```asm
Unsupported
    ; Set error condition codes
    move.b      #CCNAN,RegFpsrCc

    ; Set exception in FPSR
    ori.b       #$80,RegFpsrAexc    ; Set "unimplemented" exception

    ; Skip the faulting instruction
    INCREMENTPC #4

    ; Return from exception
    bra.w       POSTHANDLEEXCEPTION_Direct
```

**Option B: Signal to Application**
```asm
Unsupported
    ; Try to signal task with SIGBREAKF_CTRL_C
    movea.l     _AbsExecBase,a6
    suba.l      a1,a1                ; FindTask(NULL) = current task
    jsr         _LVOFindTask(a6)
    move.l      d0,a1
    move.l      #SIGBREAKF_CTRL_C,d0
    jsr         _LVOSignal(a6)

    ; Then return with error as in Option A
```

**Option C: Log and Continue**
```asm
Unsupported
    ; Write error to debug log (if DEBUG defined)
    WRITEDEBUG  #MSGUNSUPPORTED,a0,...

    ; Return NaN result
    move.l      #$7ff80000,d0
    move.l      #$00000000,d1

    ; Update destination register
    GETREGISTER d5
    MOVEDNTOFPN d5,d0,d1

    ; Continue execution
    bra.w       POSTHANDLEEXCEPTION_Direct
```

**Recommendation:** Implement Option C with compile-time choice
**Time Estimate:** 3-4 hours

---

## Priority 4: Stack Operation Optimization

### Current Performance
STACKSL/STACKSR use byte-by-byte copying:
```asm
.Loop:
    move.b      (a0),(a0,\1.l)
    adda.l      #1,a0
    cmpa.l      a0,a1
    bgt.s       .Loop
```

**Benchmark:** ~80 cycles per 16 bytes on 68040

### Optimized Version
```asm
STACKSL_OPTIMIZED macro
    ; Check alignment
    move.l      sp,d0
    andi.l      #3,d0
    bne.w       .ByteCopy           ; Fall back if unaligned

    ; Calculate long count
    movea.l     sp,a0
    movea.l     STACKFRAME,a1
    adda.l      #STACKLENGTH,a1
    move.l      a1,d0
    sub.l       a0,d0
    lsr.l       #2,d0               ; Divide by 4
    beq.s       .Done
    subq.l      #1,d0               ; For dbra

    ; Copy longs
    neg.l       \1
.LongLoop:
    move.l      (a0),(a0,\1.l)
    addq.l      #4,a0
    dbra        d0,.LongLoop
    neg.l       \1
    bra.s       .Done

.ByteCopy:
    ; [existing byte-by-byte code]

.Done:
    ; [existing pointer updates]
endm
```

**Expected Gain:** ~20 cycles per 16 bytes (4x improvement)
**Time Estimate:** 4-6 hours (testing critical)

---

## Priority 5: Comprehensive Test Suite

### Test Categories

**1. Basic Operations**
```asm
; Test each operation with:
; - Normal values
; - Edge cases (±0, ±Inf, NaN)
; - Denormals
; - Boundary exponents
```

**2. Addressing Modes**
```asm
; Test all EA modes:
; - Register direct
; - Register indirect
; - Predecrement/postincrement
; - Displacement modes
; - Immediate
```

**3. Exception Conditions**
```asm
; Verify FPSR flags:
; - Overflow
; - Underflow
; - Division by zero
; - Invalid operation
; - Inexact result
```

**4. CPU Variants**
```asm
; Separate test runs for:
; - 68020 build
; - 68040 build
; - 68080 build
```

**Test Framework Structure:**
```asm
TestSuite:
    ; Initialize test counters
    move.l      #0,TestsPassed
    move.l      #0,TestsFailed

    ; Run test groups
    jsr         TestBasicOps
    jsr         TestAddressingModes
    jsr         TestExceptions
    jsr         TestEdgeCases

    ; Report results
    jsr         PrintTestResults
    rts

TestBasicOps:
    ; FADD tests
    TEST_OP     fadd,#1.0,#2.0,#3.0,"FADD: 1+2=3"
    TEST_OP     fadd,#-1.0,#1.0,#0.0,"FADD: -1+1=0"
    ; ... more tests
    rts
```

**Time Estimate:** 20-30 hours

---

## Implementation Timeline

### Week 1-2: Core Math Operations
- [ ] Day 1-3: fdiv implementation and testing
- [ ] Day 4-5: fmul implementation and testing
- [ ] Day 6-7: fsqrt implementation and testing

### Week 3: Constants and Error Handling
- [ ] Day 8-9: FPU constant ROM completion
- [ ] Day 10-11: Error handling improvement
- [ ] Day 12-14: Stack operation optimization

### Week 4: Testing and Documentation
- [ ] Day 15-18: Test suite development
- [ ] Day 19-20: Documentation updates
- [ ] Day 21: Final integration and release

---

## Testing Strategy

### Phase 1: Unit Tests (Per Operation)
```
Test Input → FPU Operation → Verify Output
Compare against known good values
```

### Phase 2: Integration Tests
```
Run ftest.asm suite
Test with real software (games, demos, utilities)
```

### Phase 3: Stress Tests
```
Random input generation
Boundary condition fuzzing
Long-running stability tests
```

### Phase 4: Compatibility Tests
```
Cross-check with:
- UAE emulation
- Real 68882 hardware (if available)
- Motorola test vectors
```

---

## Success Criteria

### Minimum Viable Product
- ✅ All critical bugs fixed
- ✅ Basic operations functional
- ⏳ NOMATHLIB builds don't crash (in progress)
- ⏳ Error handling doesn't halt system

### Production Ready
- ⏳ All math operations implemented
- ⏳ FPU constant ROM complete
- ⏳ Comprehensive test coverage
- ⏳ Performance optimizations applied
- ⏳ Documentation complete

### Optimization Complete
- ⏳ Stack operations optimized
- ⏳ Direct 080 vectors maximized
- ⏳ Cache-friendly data layout
- ⏳ Benchmarked vs. alternatives

---

## Resource Requirements

### Development Tools
- VASM assembler (m68k)
- vlink linker
- UAE debugger
- Git version control

### Testing Environment
- WinUAE or FS-UAE
- AmigaOS 3.1+ installation
- Math libraries (for comparison)
- Vampire 68080 hardware (optional)

### Documentation Tools
- Motorola 68882 manual
- IEEE 754 specification
- AmigaOS 3.1 developer docs

---

## Risk Mitigation

### Risk: Incorrect Math Implementation
**Mitigation:** Cross-verify against multiple references, comprehensive testing

### Risk: Performance Degradation
**Mitigation:** Benchmark before/after, profiling, optimization passes

### Risk: Compatibility Issues
**Mitigation:** Test on multiple CPU variants, UAE configurations

### Risk: Regression Bugs
**Mitigation:** Maintain test suite, CI/CD if possible

---

## Next Immediate Steps

1. **Create feature branch** for division implementation
2. **Implement FE_FDIV** macro with full algorithm
3. **Write division test cases** (10-15 tests)
4. **Verify against IEEE 754** compliance
5. **Merge and repeat** for multiplication

Ready to begin implementation upon approval.
