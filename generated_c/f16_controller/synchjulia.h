#ifndef SYNCHJULIA_H
#define SYNCHJULIA_H

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <string.h>

/* `__extension__` keeps `-pedantic-errors` builds (gcc) quiet about __int128. */
__extension__ typedef __int128 synch_int128_t;
__extension__ typedef unsigned __int128 synch_uint128_t;

/* Generated Julia throws and unreachable paths terminate here. */
__attribute__((noreturn))
static inline void synch_fatal(const char *msg) {
    // cppcheck-suppress misra-c2012-21.6
    (void)fprintf(stderr, "fatal error: %s\n", msg);
    // cppcheck-suppress misra-c2012-21.8
    abort();
}

/* Bit operations with defined behavior at zero. */

static inline uint64_t synch_ctpop_u64(uint64_t x) {
    uint64_t ux = x;
    ux -= (ux >> 1U) & 0x5555555555555555ULL;
    ux = (ux & 0x3333333333333333ULL) + ((ux >> 2U) & 0x3333333333333333ULL);
    ux = (ux + (ux >> 4U)) & 0x0f0f0f0f0f0f0f0fULL;
    return (ux * 0x0101010101010101ULL) >> 56U;
}

static inline uint64_t synch_ctlz_u64(uint64_t x) {
    /* Smear the highest set bit downward, then count what's left clear. */
    uint64_t ux = x;
    ux |= ux >> 1U;
    ux |= ux >> 2U;
    ux |= ux >> 4U;
    ux |= ux >> 8U;
    ux |= ux >> 16U;
    ux |= ux >> 32U;
    return synch_ctpop_u64(~ux);
}

static inline uint64_t synch_cttz_u64(uint64_t x) {
    /* Bits strictly below the lowest set bit; all 64 when x is 0. */
    return synch_ctpop_u64(~x & (x - 1ULL));
}

static inline uint64_t synch_bswap_u64(uint64_t x) {
    uint64_t ux = x;
    ux = ((ux & 0x00ff00ff00ff00ffULL) << 8U) | ((ux >> 8U) & 0x00ff00ff00ff00ffULL);
    ux = ((ux & 0x0000ffff0000ffffULL) << 16U) | ((ux >> 16U) & 0x0000ffff0000ffffULL);
    return (ux << 32U) | (ux >> 32U);
}

static inline synch_uint128_t synch_u128_from_words(uint64_t hi, uint64_t lo) {
    return ((synch_uint128_t)hi << 64U) | (synch_uint128_t)lo;
}

static inline synch_int128_t synch_i128_from_words(uint64_t hi, uint64_t lo) {
    synch_uint128_t u = synch_u128_from_words(hi, lo);
    synch_int128_t r;
    // cppcheck-suppress misra-c2012-21.15 ; representation-preserving conversion
    (void)memcpy(&r, &u, sizeof(r));
    return r;
}

#endif
