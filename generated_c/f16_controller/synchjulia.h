#ifndef SYNCHJULIA_H
#define SYNCHJULIA_H

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <string.h>

/* Abort with a diagnostic — the generated code's trap path (Julia `throw`
 * and unreachable control flow). The two local suppressions are the project's
 * deliberate runtime-trap deviation: keep the diagnostic and terminate. */
__attribute__((noreturn))
static inline void synch_fatal(const char *msg) {
    // cppcheck-suppress misra-c2012-21.6
    (void)fprintf(stderr, "fatal error: %s\n", msg);
    // cppcheck-suppress misra-c2012-21.8
    abort();
}

static inline int64_t synch_clamp_i64(int64_t x, int64_t lo, int64_t hi) {
    int64_t y;
    if (x < lo) {
        y = lo;
    } else if (x > hi) {
        y = hi;
    } else {
        y = x;
    }
    return y;
}

/* Shifts on signed operands route through unsigned arithmetic: C leaves
 * signed shifts undefined/implementation-defined there, and MISRA C:2012
 * Rule 10.1 requires essentially unsigned shift operands.
 *
 * Precondition: n < width (64 or 32). Overshifting is still undefined
 * behavior in C; these helpers mirror Julia's shift intrinsics, whose
 * callers (e.g. `<<`, `>>`) guard the shift amount before reaching them. */

static inline int64_t synch_shl_i64(int64_t x, uint64_t n) {
    uint64_t ux = (uint64_t)x;
    uint64_t shifted = ux << n;
    return (int64_t)shifted;
}

static inline int64_t synch_lshr_i64(int64_t x, uint64_t n) {
    uint64_t ux = (uint64_t)x;
    uint64_t shifted = ux >> n;
    return (int64_t)shifted;
}

static inline int64_t synch_ashr_i64(int64_t x, uint64_t n) {
    uint64_t ux = (uint64_t)x;
    uint64_t shifted;
    if (x < 0LL) {
        shifted = ~(~ux >> n);
    } else {
        shifted = ux >> n;
    }
    return (int64_t)shifted;
}

static inline int32_t synch_shl_i32(int32_t x, uint32_t n) {
    uint32_t ux = (uint32_t)x;
    uint32_t shifted = ux << n;
    return (int32_t)shifted;
}

static inline int32_t synch_lshr_i32(int32_t x, uint32_t n) {
    uint32_t ux = (uint32_t)x;
    uint32_t shifted = ux >> n;
    return (int32_t)shifted;
}

static inline int32_t synch_ashr_i32(int32_t x, uint32_t n) {
    uint32_t ux = (uint32_t)x;
    uint32_t shifted;
    if (x < 0) {
        shifted = ~(~ux >> n);
    } else {
        shifted = ux >> n;
    }
    return (int32_t)shifted;
}

/* Bit manipulation helpers — branch-free bit-twiddling forms (Hacker's
 * Delight) with defined behavior at 0. Straight-line unsigned arithmetic
 * keeps them MISRA-clean, and compilers idiom-recognize them back into the
 * single popcount/byte-reverse instructions where available. */

static inline int64_t synch_ctpop_i64(int64_t x) {
    uint64_t ux = (uint64_t)x;
    ux -= (ux >> 1U) & 0x5555555555555555ULL;
    ux = (ux & 0x3333333333333333ULL) + ((ux >> 2U) & 0x3333333333333333ULL);
    ux = (ux + (ux >> 4U)) & 0x0f0f0f0f0f0f0f0fULL;
    uint64_t count = (ux * 0x0101010101010101ULL) >> 56U;
    return (int64_t)count;
}

static inline int64_t synch_ctlz_i64(int64_t x) {
    /* Smear the highest set bit downward, then count what's left clear. */
    uint64_t ux = (uint64_t)x;
    ux |= ux >> 1U;
    ux |= ux >> 2U;
    ux |= ux >> 4U;
    ux |= ux >> 8U;
    ux |= ux >> 16U;
    ux |= ux >> 32U;
    uint64_t cleared = ~ux;
    return synch_ctpop_i64((int64_t)cleared);
}

static inline int64_t synch_cttz_i64(int64_t x) {
    /* Bits strictly below the lowest set bit; all 64 when x is 0. */
    uint64_t ux = (uint64_t)x;
    uint64_t below = ~ux & (ux - 1ULL);
    return synch_ctpop_i64((int64_t)below);
}

static inline int64_t synch_bswap_i64(int64_t x) {
    uint64_t ux = (uint64_t)x;
    ux = ((ux & 0x00ff00ff00ff00ffULL) << 8U) | ((ux >> 8U) & 0x00ff00ff00ff00ffULL);
    ux = ((ux & 0x0000ffff0000ffffULL) << 16U) | ((ux >> 16U) & 0x0000ffff0000ffffULL);
    ux = (ux << 32U) | (ux >> 32U);
    return (int64_t)ux;
}

static inline int64_t synch_flipsign_i64(int64_t a, int64_t b) {
    int64_t out = a;
    if (b < 0LL) {
        out = -a;
    }
    return out;
}

#endif
