#ifndef TOP_H
#define TOP_H

#include "synchjulia.h"

typedef struct {
double elements[5];
} julia_NTuple_5_double;
typedef struct {
julia_NTuple_5_double data;
} syncharray_Float64_5;
typedef struct {
int64_t elements[1];
} julia_NTuple_1_int64_t;
typedef struct {
double elements[12];
} julia_NTuple_12_double;
typedef struct {
julia_NTuple_12_double data;
} syncharray_Float64_12;
typedef struct {
double elements[144];
} julia_NTuple_144_double;
typedef struct {
julia_NTuple_144_double data;
} syncharray_Float64_12x12;
typedef struct {
int64_t elements[2];
} julia_NTuple_2_int64_t;
typedef struct {
double elements[60];
} julia_NTuple_60_double;
typedef struct {
julia_NTuple_60_double data;
} syncharray_Float64_5x12;

typedef struct {
double output_demux_y1_t_;
double output_demux_y2_t_;
double output_demux_y3_t_;
double output_demux_y4_t_;
double output_demux_y5_t_;
/* presence of output_demux₊y1(t); false means absent this tick */
bool has_output_demux_y1_t_;
/* presence of output_demux₊y2(t); false means absent this tick */
bool has_output_demux_y2_t_;
/* presence of output_demux₊y3(t); false means absent this tick */
bool has_output_demux_y3_t_;
/* presence of output_demux₊y4(t); false means absent this tick */
bool has_output_demux_y4_t_;
/* presence of output_demux₊y5(t); false means absent this tick */
bool has_output_demux_y5_t_;
} z3top_t7Float64_t7Float64_t7Float64_0f1ef30da8f01d18_out;

typedef struct {
bool first_tick_2;
syncharray_Float64_12 controller_controller_x_t_;
} z3top_t7Float64_t7Float64_t7Float64_0f1ef30da8f01d18_mem;

z3top_t7Float64_t7Float64_t7Float64_0f1ef30da8f01d18_out z3top_t7Float64_t7Float64_t7Float64_0f1ef30da8f01d18_step(double input_mux_u1_t_, double input_mux_u2_t_, double input_mux_u3_t_, double input_mux_u4_t_, double input_mux_u5_t_, double input_mux_u6_t_, double input_mux_u7_t_, double input_mux_u8_t_, double input_mux_u9_t_, double input_mux_u10_t_, double input_mux_u11_t_, double input_mux_u12_t_, bool clock1, int64_t c_auto, z3top_t7Float64_t7Float64_t7Float64_0f1ef30da8f01d18_mem* self);
void z3top_t7Float64_t7Float64_t7Float64_0f1ef30da8f01d18_reset(z3top_t7Float64_t7Float64_t7Float64_0f1ef30da8f01d18_mem* self);
extern const size_t z3top_t7Float64_t7Float64_t7Float64_0f1ef30da8f01d18_state_size;
#endif // TOP_H
