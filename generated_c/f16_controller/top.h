#ifndef SYNCHJULIA_top_H
#define SYNCHJULIA_top_H

#include "synchjulia.h"

typedef struct AutoPars AutoPars;

typedef struct {
double elements[5];
} NTuple5_f64;
typedef struct {
NTuple5_f64 data;
} SynchArray_f64x5;
typedef struct {
double elements[144];
} NTuple144_f64;
typedef struct {
NTuple144_f64 data;
} SynchArray_f64x12x12;
typedef struct {
double elements[12];
} NTuple12_f64;
typedef struct {
NTuple12_f64 data;
} SynchArray_f64x12;
typedef struct {
double elements[60];
} NTuple60_f64;
typedef struct {
NTuple60_f64 data;
} SynchArray_f64x5x12;

/* mutable struct SynchToolkit.var"##SynchRuntime#277".AutoPars */
struct AutoPars {
SynchArray_f64x12x12 controller_controller_A;
SynchArray_f64x12x12 controller_controller_B;
SynchArray_f64x5x12 controller_controller_C;
SynchArray_f64x5x12 controller_controller_D;
SynchArray_f64x12 controller_controller_u0;
SynchArray_f64x5 controller_controller_y0;
};

typedef struct {
double output_demux_y1_u28_t_u29;
double output_demux_y2_u28_t_u29;
double output_demux_y3_u28_t_u29;
double output_demux_y4_u28_t_u29;
double output_demux_y5_u28_t_u29;
/* presence of output_demux₊y1(t); false means absent this tick */
bool has_output_demux_y1_u28_t_u29;
/* presence of output_demux₊y2(t); false means absent this tick */
bool has_output_demux_y2_u28_t_u29;
/* presence of output_demux₊y3(t); false means absent this tick */
bool has_output_demux_y3_u28_t_u29;
/* presence of output_demux₊y4(t); false means absent this tick */
bool has_output_demux_y4_u28_t_u29;
/* presence of output_demux₊y5(t); false means absent this tick */
bool has_output_demux_y5_u28_t_u29;
} top_f64_f64_f64_f64_f64_f64_f64_f64_8a697563b70ba2db_out;

typedef struct {
bool first_tick_3;
SynchArray_f64x12 controller_controller_x_u28_t_u29;
} top_f64_f64_f64_f64_f64_f64_f64_f64_8a697563b70ba2db_mem;

top_f64_f64_f64_f64_f64_f64_f64_f64_8a697563b70ba2db_out top_f64_f64_f64_f64_f64_f64_f64_f64_8a697563b70ba2db_step(double input_mux_u1_u28_t_u29, double input_mux_u2_u28_t_u29, double input_mux_u3_u28_t_u29, double input_mux_u4_u28_t_u29, double input_mux_u5_u28_t_u29, double input_mux_u6_u28_t_u29, double input_mux_u7_u28_t_u29, double input_mux_u8_u28_t_u29, double input_mux_u9_u28_t_u29, double input_mux_u10_u28_t_u29, double input_mux_u11_u28_t_u29, double input_mux_u12_u28_t_u29, bool clock1, AutoPars * auto_, top_f64_f64_f64_f64_f64_f64_f64_f64_8a697563b70ba2db_mem* self);
void top_f64_f64_f64_f64_f64_f64_f64_f64_8a697563b70ba2db_reset(top_f64_f64_f64_f64_f64_f64_f64_f64_8a697563b70ba2db_mem* self);
extern const size_t top_f64_f64_f64_f64_f64_f64_f64_f64_8a697563b70ba2db_state_size;
#endif // SYNCHJULIA_top_H
