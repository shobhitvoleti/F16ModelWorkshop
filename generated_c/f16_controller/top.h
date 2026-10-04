#ifndef SYNCHJULIA_top_H
#define SYNCHJULIA_top_H

#include "synchjulia.h"

typedef struct Pars Pars;

typedef struct {
double elements[5];
} NTuple5_f64;
typedef struct {
NTuple5_f64 data;
} SynchArray_f64x5;
typedef struct {
double elements[60];
} NTuple60_f64;
typedef struct {
NTuple60_f64 data;
} SynchArray_f64x5x12;
typedef struct {
double elements[12];
} NTuple12_f64;
typedef struct {
NTuple12_f64 data;
} SynchArray_f64x12;
typedef struct {
double elements[144];
} NTuple144_f64;
typedef struct {
NTuple144_f64 data;
} SynchArray_f64x12x12;
typedef struct {
double elements[1];
} NTuple1_f64;

/* mutable struct SynchToolkit.var"##SynchRuntime#277".Pars */
struct Pars {
SynchArray_f64x12x12 controller_A;
SynchArray_f64x12x12 controller_B;
SynchArray_f64x5x12 controller_C;
SynchArray_f64x5x12 controller_D;
SynchArray_f64x12 controller_u0;
SynchArray_f64x5 controller_y0;
};

typedef struct {
SynchArray_f64x5 u28_y_u28_t_u29_u29_u5b_1_colon_5_u5d;
/* presence of (y(t))[1:5]; false means absent this tick */
bool has_u28_y_u28_t_u29_u29_u5b_1_colon_5_u5d;
} top_f64x12_bool_Pars_out;

typedef struct {
bool first_tick_3;
SynchArray_f64x12 controller_x_u28_t_u29;
} top_f64x12_bool_Pars_mem;

/* top_f64x12_bool_Pars_step: implementation step for the in-process runtime
 * and existing callers. Takes generated value structs and returns
 * top_f64x12_bool_Pars_out by value. C callers should use top_f64x12_bool_Pars_step_c. */
top_f64x12_bool_Pars_out top_f64x12_bool_Pars_step(SynchArray_f64x12 u28_u_u28_t_u29_u29_u5b_1_colon_12_u5d, bool clock1, Pars * pars, top_f64x12_bool_Pars_mem* self);

// clang-format off
/* top_f64x12_bool_Pars_step_c: C interface. Parameters follow declaration order:
 * inputs, outputs, then state:
 *   (u(t))[1:12] : SynchJulia.SynchVector{Float64, 12} -> const double u28_u_u28_t_u29_u29_u5b_1_colon_12_u5d[12] (input buffer, 12 elements)
 *   clock1 : Bool -> bool clock1 (input value)
 *   pars : SynchToolkit.var"##SynchRuntime#277".Pars -> Pars *pars (input object, by pointer)
 *   (y(t))[1:5] : SynchJulia.SynchVector{Float64, 5} -> double u28_y_u28_t_u29_u29_u5b_1_colon_5_u5d[5] (output buffer, 5 elements)
 *   (y(t))[1:5] presence -> bool *has_u28_y_u28_t_u29_u29_u5b_1_colon_5_u5d (output; false means absent this tick)
 *   state -> top_f64x12_bool_Pars_mem *self (reset with top_f64x12_bool_Pars_reset before the first tick)
 *
 * Storage parameters (buffers, inputs read through a pointer, output and presence
 * destinations, and state) must be non-null, aligned for their type, hold the
 * stated number of elements, and remain valid until the call returns. Outputs,
 * presence flags and the state must not overlap each other or input storage.
 * The call copies buffers into the node's value types, runs top_f64x12_bool_Pars_step
 * once, and copies present outputs back. The adapter retains no buffer pointers.
 * A clocked output's presence flag is always written; its payload only when
 * present. An absent tick leaves the destination unchanged.
 * Object inputs preserve identity and mutability.
 * The node may dereference, modify or retain signal pointers and object references,
 * including those inside aggregates. Their referents must remain valid for those
 * accesses, which must also obey the non-overlap requirements above.
 */
// clang-format on
void top_f64x12_bool_Pars_step_c(const double u28_u_u28_t_u29_u29_u5b_1_colon_12_u5d[12], bool clock1, Pars * pars, double u28_y_u28_t_u29_u29_u5b_1_colon_5_u5d[5], bool * has_u28_y_u28_t_u29_u29_u5b_1_colon_5_u5d, top_f64x12_bool_Pars_mem * self);

void top_f64x12_bool_Pars_reset(top_f64x12_bool_Pars_mem* self);
extern const size_t top_f64x12_bool_Pars_state_size;
#endif // SYNCHJULIA_top_H
