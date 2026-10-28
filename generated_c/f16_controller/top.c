#include "top.h"

static double getindex_f64x5_i64_70864f0d(SynchArray_f64x5 a, int64_t i);
static double getindex_f64x5_i64_8a6206c2(SynchArray_f64x5 a, int64_t i);
static double getindex_f64x5_i64_9cb6e4c6(SynchArray_f64x5 a, int64_t i);
static double getindex_f64x5_i64_f1365eec(SynchArray_f64x5 a, int64_t i);
static double getindex_f64x5_i64_28cdea89(SynchArray_f64x5 a, int64_t i);
static SynchArray_f64x5 vcat_f64_f64_f64_f64_f64(double args_1, double args_2, double args_3, double args_4, double args_5);
static SynchArray_f64x12 broadcast_minus_f64x12_f64x12_56715569(SynchArray_f64x12 As_1, SynchArray_f64x12 As_2);
static SynchArray_f64x5 mul_f64x5x12_f64x12(SynchArray_f64x5x12 a, SynchArray_f64x12 b);
static SynchArray_f64x5 plus_f64x5_f64x5_f64x5(SynchArray_f64x5 a, SynchArray_f64x5 b, SynchArray_f64x5 c);
static SynchArray_f64x12 mul_f64x12x12_f64x12(SynchArray_f64x12x12 a, SynchArray_f64x12 b);
static SynchArray_f64x12 plus_f64x12_f64x12(SynchArray_f64x12 a, SynchArray_f64x12 b);
static double getindex_f64x12_i64_081010bd(SynchArray_f64x12 a, int64_t i);
static double getindex_f64x12_i64_e4285bab(SynchArray_f64x12 a, int64_t i);
static double getindex_f64x12_i64_5879170b(SynchArray_f64x12 a, int64_t i);
static double getindex_f64x12_i64_adc09d26(SynchArray_f64x12 a, int64_t i);
static double getindex_f64x12_i64_c29abda5(SynchArray_f64x12 a, int64_t i);
static double getindex_f64x12_i64_798c8438(SynchArray_f64x12 a, int64_t i);
static double getindex_f64x12_i64_36f60a18(SynchArray_f64x12 a, int64_t i);
static double getindex_f64x12_i64_70864f0d(SynchArray_f64x12 a, int64_t i);
static double getindex_f64x12_i64_8a6206c2(SynchArray_f64x12 a, int64_t i);
static double getindex_f64x12_i64_9cb6e4c6(SynchArray_f64x12 a, int64_t i);
static double getindex_f64x12_i64_f1365eec(SynchArray_f64x12 a, int64_t i);
static double getindex_f64x12_i64_28cdea89(SynchArray_f64x12 a, int64_t i);
static SynchArray_f64x12 vcat_f64_f64_f64_f64_f64_f64_f64_f64_f64_f64_f64_f64(double args_1, double args_2, double args_3, double args_4, double args_5, double args_6, double args_7, double args_8, double args_9, double args_10, double args_11, double args_12);

/* function getindex(a::SynchJulia.SynchVector{Float64, 5}, i::Int64) at /Users/shobhitvoleti/.julia/packages/SynchJulia/Q957d/src/runtime/array.jl:132 */
static double getindex_f64x5_i64_70864f0d(SynchArray_f64x5 a, int64_t i) {
bool ssa_1;
bool ssa_5;
double ssa_6;
(void)i;
/* SSA %1 in getindex */
ssa_1 = true;

/* SSA %8 in getindex */
if (ssa_1) {

/* SSA %3 in getindex */
}

/* SSA %5 in getindex */
ssa_5 = false;

/* SSA %6 in getindex */
ssa_6 = a.data.elements[4];

/* SSA %7 in getindex */
// cppcheck-suppress misra-c2012-15.5 ; structured Julia control flow
return ssa_6;
}

/* function getindex(a::SynchJulia.SynchVector{Float64, 5}, i::Int64) at /Users/shobhitvoleti/.julia/packages/SynchJulia/Q957d/src/runtime/array.jl:132 */
static double getindex_f64x5_i64_8a6206c2(SynchArray_f64x5 a, int64_t i) {
bool ssa_1;
bool ssa_5;
double ssa_6;
(void)i;
/* SSA %1 in getindex */
ssa_1 = true;

/* SSA %8 in getindex */
if (ssa_1) {

/* SSA %3 in getindex */
}

/* SSA %5 in getindex */
ssa_5 = false;

/* SSA %6 in getindex */
ssa_6 = a.data.elements[3];

/* SSA %7 in getindex */
// cppcheck-suppress misra-c2012-15.5 ; structured Julia control flow
return ssa_6;
}

/* function getindex(a::SynchJulia.SynchVector{Float64, 5}, i::Int64) at /Users/shobhitvoleti/.julia/packages/SynchJulia/Q957d/src/runtime/array.jl:132 */
static double getindex_f64x5_i64_9cb6e4c6(SynchArray_f64x5 a, int64_t i) {
bool ssa_1;
bool ssa_5;
double ssa_6;
(void)i;
/* SSA %1 in getindex */
ssa_1 = true;

/* SSA %8 in getindex */
if (ssa_1) {

/* SSA %3 in getindex */
}

/* SSA %5 in getindex */
ssa_5 = false;

/* SSA %6 in getindex */
ssa_6 = a.data.elements[2];

/* SSA %7 in getindex */
// cppcheck-suppress misra-c2012-15.5 ; structured Julia control flow
return ssa_6;
}

/* function getindex(a::SynchJulia.SynchVector{Float64, 5}, i::Int64) at /Users/shobhitvoleti/.julia/packages/SynchJulia/Q957d/src/runtime/array.jl:132 */
static double getindex_f64x5_i64_f1365eec(SynchArray_f64x5 a, int64_t i) {
bool ssa_1;
bool ssa_5;
double ssa_6;
(void)i;
/* SSA %1 in getindex */
ssa_1 = true;

/* SSA %8 in getindex */
if (ssa_1) {

/* SSA %3 in getindex */
}

/* SSA %5 in getindex */
ssa_5 = false;

/* SSA %6 in getindex */
ssa_6 = a.data.elements[1];

/* SSA %7 in getindex */
// cppcheck-suppress misra-c2012-15.5 ; structured Julia control flow
return ssa_6;
}

/* function getindex(a::SynchJulia.SynchVector{Float64, 5}, i::Int64) at /Users/shobhitvoleti/.julia/packages/SynchJulia/Q957d/src/runtime/array.jl:132 */
static double getindex_f64x5_i64_28cdea89(SynchArray_f64x5 a, int64_t i) {
bool ssa_1;
bool ssa_5;
double ssa_6;
(void)i;
/* SSA %1 in getindex */
ssa_1 = true;

/* SSA %8 in getindex */
if (ssa_1) {

/* SSA %3 in getindex */
}

/* SSA %5 in getindex */
ssa_5 = false;

/* SSA %6 in getindex */
ssa_6 = a.data.elements[0];

/* SSA %7 in getindex */
// cppcheck-suppress misra-c2012-15.5 ; structured Julia control flow
return ssa_6;
}

/* function vcat(args_1::Float64, args_2::Float64, args_3::Float64, args_4::Float64, args_5::Float64) at /Users/shobhitvoleti/.julia/packages/SynchJulia/Q957d/src/runtime/builtins.jl:54 */
static SynchArray_f64x5 vcat_f64_f64_f64_f64_f64(double args_1, double args_2, double args_3, double args_4, double args_5) {
SynchArray_f64x5 ssa_1;
/* SSA %1 in vcat */
ssa_1 = (SynchArray_f64x5){ (NTuple5_f64){ .elements = { args_1, args_2, args_3, args_4, args_5 } } };

/* SSA %2 in vcat */
// cppcheck-suppress misra-c2012-15.5 ; structured Julia control flow
return ssa_1;
}

/* function broadcast(f::typeof(-), As_1::SynchJulia.SynchVector{Float64, 12}, As_2::SynchJulia.SynchVector{Float64, 12}) at broadcast.jl:837 */
static SynchArray_f64x12 broadcast_minus_f64x12_f64x12_56715569(SynchArray_f64x12 As_1, SynchArray_f64x12 As_2) {
SynchArray_f64x12 ssa_1;
SynchArray_f64x12 ssa_2;
bool ssa_4;
double ssa_5;
bool ssa_7;
double ssa_8;
double ssa_9;
bool ssa_11;
double ssa_12;
bool ssa_14;
double ssa_15;
double ssa_16;
bool ssa_18;
double ssa_19;
bool ssa_21;
double ssa_22;
double ssa_23;
bool ssa_25;
double ssa_26;
bool ssa_28;
double ssa_29;
double ssa_30;
bool ssa_32;
double ssa_33;
bool ssa_35;
double ssa_36;
double ssa_37;
bool ssa_39;
double ssa_40;
bool ssa_42;
double ssa_43;
double ssa_44;
bool ssa_46;
double ssa_47;
bool ssa_49;
double ssa_50;
double ssa_51;
bool ssa_53;
double ssa_54;
bool ssa_56;
double ssa_57;
double ssa_58;
bool ssa_60;
double ssa_61;
bool ssa_63;
double ssa_64;
double ssa_65;
bool ssa_67;
double ssa_68;
bool ssa_70;
double ssa_71;
double ssa_72;
bool ssa_74;
double ssa_75;
bool ssa_77;
double ssa_78;
double ssa_79;
bool ssa_81;
double ssa_82;
bool ssa_84;
double ssa_85;
double ssa_86;
NTuple12_f64 ssa_87;
SynchArray_f64x12 ssa_88;
/* SSA %1 in broadcast */
ssa_1 = As_1;

/* SSA %2 in broadcast */
ssa_2 = As_2;

/* SSA %4 in broadcast */
ssa_4 = true;

/* SSA %5 in broadcast */
ssa_5 = ssa_1.data.elements[0];

/* SSA %7 in broadcast */
ssa_7 = true;

/* SSA %8 in broadcast */
ssa_8 = ssa_2.data.elements[0];

/* SSA %9 in broadcast */
ssa_9 = ((ssa_5) - (ssa_8));

/* SSA %11 in broadcast */
ssa_11 = true;

/* SSA %12 in broadcast */
ssa_12 = ssa_1.data.elements[1];

/* SSA %14 in broadcast */
ssa_14 = true;

/* SSA %15 in broadcast */
ssa_15 = ssa_2.data.elements[1];

/* SSA %16 in broadcast */
ssa_16 = ((ssa_12) - (ssa_15));

/* SSA %18 in broadcast */
ssa_18 = true;

/* SSA %19 in broadcast */
ssa_19 = ssa_1.data.elements[2];

/* SSA %21 in broadcast */
ssa_21 = true;

/* SSA %22 in broadcast */
ssa_22 = ssa_2.data.elements[2];

/* SSA %23 in broadcast */
ssa_23 = ((ssa_19) - (ssa_22));

/* SSA %25 in broadcast */
ssa_25 = true;

/* SSA %26 in broadcast */
ssa_26 = ssa_1.data.elements[3];

/* SSA %28 in broadcast */
ssa_28 = true;

/* SSA %29 in broadcast */
ssa_29 = ssa_2.data.elements[3];

/* SSA %30 in broadcast */
ssa_30 = ((ssa_26) - (ssa_29));

/* SSA %32 in broadcast */
ssa_32 = true;

/* SSA %33 in broadcast */
ssa_33 = ssa_1.data.elements[4];

/* SSA %35 in broadcast */
ssa_35 = true;

/* SSA %36 in broadcast */
ssa_36 = ssa_2.data.elements[4];

/* SSA %37 in broadcast */
ssa_37 = ((ssa_33) - (ssa_36));

/* SSA %39 in broadcast */
ssa_39 = true;

/* SSA %40 in broadcast */
ssa_40 = ssa_1.data.elements[5];

/* SSA %42 in broadcast */
ssa_42 = true;

/* SSA %43 in broadcast */
ssa_43 = ssa_2.data.elements[5];

/* SSA %44 in broadcast */
ssa_44 = ((ssa_40) - (ssa_43));

/* SSA %46 in broadcast */
ssa_46 = true;

/* SSA %47 in broadcast */
ssa_47 = ssa_1.data.elements[6];

/* SSA %49 in broadcast */
ssa_49 = true;

/* SSA %50 in broadcast */
ssa_50 = ssa_2.data.elements[6];

/* SSA %51 in broadcast */
ssa_51 = ((ssa_47) - (ssa_50));

/* SSA %53 in broadcast */
ssa_53 = true;

/* SSA %54 in broadcast */
ssa_54 = ssa_1.data.elements[7];

/* SSA %56 in broadcast */
ssa_56 = true;

/* SSA %57 in broadcast */
ssa_57 = ssa_2.data.elements[7];

/* SSA %58 in broadcast */
ssa_58 = ((ssa_54) - (ssa_57));

/* SSA %60 in broadcast */
ssa_60 = true;

/* SSA %61 in broadcast */
ssa_61 = ssa_1.data.elements[8];

/* SSA %63 in broadcast */
ssa_63 = true;

/* SSA %64 in broadcast */
ssa_64 = ssa_2.data.elements[8];

/* SSA %65 in broadcast */
ssa_65 = ((ssa_61) - (ssa_64));

/* SSA %67 in broadcast */
ssa_67 = true;

/* SSA %68 in broadcast */
ssa_68 = ssa_1.data.elements[9];

/* SSA %70 in broadcast */
ssa_70 = true;

/* SSA %71 in broadcast */
ssa_71 = ssa_2.data.elements[9];

/* SSA %72 in broadcast */
ssa_72 = ((ssa_68) - (ssa_71));

/* SSA %74 in broadcast */
ssa_74 = true;

/* SSA %75 in broadcast */
ssa_75 = ssa_1.data.elements[10];

/* SSA %77 in broadcast */
ssa_77 = true;

/* SSA %78 in broadcast */
ssa_78 = ssa_2.data.elements[10];

/* SSA %79 in broadcast */
ssa_79 = ((ssa_75) - (ssa_78));

/* SSA %81 in broadcast */
ssa_81 = true;

/* SSA %82 in broadcast */
ssa_82 = ssa_1.data.elements[11];

/* SSA %84 in broadcast */
ssa_84 = true;

/* SSA %85 in broadcast */
ssa_85 = ssa_2.data.elements[11];

/* SSA %86 in broadcast */
ssa_86 = ((ssa_82) - (ssa_85));

/* SSA %87 in broadcast */
ssa_87 = (NTuple12_f64){ .elements = { ssa_9, ssa_16, ssa_23, ssa_30, ssa_37, ssa_44, ssa_51, ssa_58, ssa_65, ssa_72, ssa_79, ssa_86 } };

/* SSA %88 in broadcast */
ssa_88 = (SynchArray_f64x12){ ssa_87 };

/* SSA %89 in broadcast */
// cppcheck-suppress misra-c2012-15.5 ; structured Julia control flow
return ssa_88;
}

/* function *(a::SynchJulia.SynchMatrix{Float64, 5, 12, 60}, b::SynchJulia.SynchVector{Float64, 12}) at /Users/shobhitvoleti/.julia/packages/SynchJulia/Q957d/src/runtime/builtins.jl:271 */
static SynchArray_f64x5 mul_f64x5x12_f64x12(SynchArray_f64x5x12 a, SynchArray_f64x12 b) {
int64_t ssa_161;
int64_t arg_21;
double arg_22;
int64_t ssa_6;
int64_t ssa_7;
int64_t ssa_8;
bool ssa_9;
double ssa_10;
bool ssa_12;
double ssa_13;
double ssa_14;
double ssa_141;
bool ssa_16;
NTuple1_f64 ssa_144;
int64_t ssa_2;
int64_t ssa_3;
double ssa_4;
double ssa_15;
int64_t ssa_162;
int64_t arg_23;
double arg_24;
int64_t ssa_33;
int64_t ssa_34;
int64_t ssa_35;
bool ssa_36;
double ssa_37;
bool ssa_39;
double ssa_40;
double ssa_41;
double ssa_145;
bool ssa_43;
NTuple1_f64 ssa_148;
int64_t ssa_29;
int64_t ssa_30;
double ssa_31;
double ssa_42;
int64_t ssa_163;
int64_t arg_25;
double arg_26;
int64_t ssa_60;
int64_t ssa_61;
int64_t ssa_62;
bool ssa_63;
double ssa_64;
bool ssa_66;
double ssa_67;
double ssa_68;
double ssa_149;
bool ssa_70;
NTuple1_f64 ssa_152;
int64_t ssa_56;
int64_t ssa_57;
double ssa_58;
double ssa_69;
int64_t ssa_164;
int64_t arg_27;
double arg_28;
int64_t ssa_87;
int64_t ssa_88;
int64_t ssa_89;
bool ssa_90;
double ssa_91;
bool ssa_93;
double ssa_94;
double ssa_95;
double ssa_153;
bool ssa_97;
NTuple1_f64 ssa_156;
int64_t ssa_83;
int64_t ssa_84;
double ssa_85;
double ssa_96;
int64_t ssa_165;
int64_t arg_29;
double arg_30;
int64_t ssa_114;
int64_t ssa_115;
int64_t ssa_116;
bool ssa_117;
double ssa_118;
bool ssa_120;
double ssa_121;
double ssa_122;
double ssa_157;
bool ssa_124;
NTuple1_f64 ssa_160;
int64_t ssa_110;
int64_t ssa_111;
double ssa_112;
double ssa_123;
NTuple5_f64 ssa_136;
SynchArray_f64x5 ssa_139;
/* SSA %1 in * */

/* SSA %161 in * */
uint64_t bitcast_src1;
bitcast_src1 = ((((uint64_t)(12LL))) + (((uint64_t)(1LL))));
// cppcheck-suppress misra-c2012-21.15 ; representation-preserving bitcast
(void)memcpy(&ssa_161, &bitcast_src1, sizeof(ssa_161));

/* SSA %144 in * */
arg_22 = 0.0;
for (arg_21 = 1LL; arg_21 < ssa_161; arg_21 += 1LL) {

/* SSA %6 in * */
uint64_t bitcast_src2;
bitcast_src2 = ((((uint64_t)(arg_21))) - (((uint64_t)(1LL))));
// cppcheck-suppress misra-c2012-21.15 ; representation-preserving bitcast
(void)memcpy(&ssa_6, &bitcast_src2, sizeof(ssa_6));

/* SSA %7 in * */
uint64_t bitcast_src3;
bitcast_src3 = ((((uint64_t)(ssa_6))) * (((uint64_t)(5LL))));
// cppcheck-suppress misra-c2012-21.15 ; representation-preserving bitcast
(void)memcpy(&ssa_7, &bitcast_src3, sizeof(ssa_7));

/* SSA %8 in * */
uint64_t bitcast_src4;
bitcast_src4 = ((((uint64_t)(ssa_7))) + (((uint64_t)(1LL))));
// cppcheck-suppress misra-c2012-21.15 ; representation-preserving bitcast
(void)memcpy(&ssa_8, &bitcast_src4, sizeof(ssa_8));

/* SSA %9 in * */
ssa_9 = false;

/* SSA %10 in * */
ssa_10 = a.data.elements[(ssa_8) - 1];

/* SSA %12 in * */
ssa_12 = false;

/* SSA %13 in * */
ssa_13 = b.data.elements[(arg_21) - 1];

/* SSA %14 in * */
ssa_14 = ((ssa_10) * (ssa_13));

/* SSA %141 in * */
ssa_141 = ((arg_22) + (ssa_14));

/* SSA %16 in * */
ssa_16 = ((arg_21) == (12LL));

/* SSA %144 in * */
arg_22 = ssa_141;
}
ssa_144 = (NTuple1_f64){ .elements = { arg_22 } };

/* SSA %2 in * */
ssa_2 = ssa_161;

/* SSA %3 in * */
ssa_3 = ssa_161;

/* SSA %4 in * */
ssa_4 = ssa_144.elements[0];

/* SSA %15 in * */
ssa_15 = ssa_144.elements[0];

/* SSA %28 in * */

/* SSA %162 in * */
uint64_t bitcast_src5;
bitcast_src5 = ((((uint64_t)(12LL))) + (((uint64_t)(1LL))));
// cppcheck-suppress misra-c2012-21.15 ; representation-preserving bitcast
(void)memcpy(&ssa_162, &bitcast_src5, sizeof(ssa_162));

/* SSA %148 in * */
arg_24 = 0.0;
for (arg_23 = 1LL; arg_23 < ssa_162; arg_23 += 1LL) {

/* SSA %33 in * */
uint64_t bitcast_src6;
bitcast_src6 = ((((uint64_t)(arg_23))) - (((uint64_t)(1LL))));
// cppcheck-suppress misra-c2012-21.15 ; representation-preserving bitcast
(void)memcpy(&ssa_33, &bitcast_src6, sizeof(ssa_33));

/* SSA %34 in * */
uint64_t bitcast_src7;
bitcast_src7 = ((((uint64_t)(ssa_33))) * (((uint64_t)(5LL))));
// cppcheck-suppress misra-c2012-21.15 ; representation-preserving bitcast
(void)memcpy(&ssa_34, &bitcast_src7, sizeof(ssa_34));

/* SSA %35 in * */
uint64_t bitcast_src8;
bitcast_src8 = ((((uint64_t)(ssa_34))) + (((uint64_t)(2LL))));
// cppcheck-suppress misra-c2012-21.15 ; representation-preserving bitcast
(void)memcpy(&ssa_35, &bitcast_src8, sizeof(ssa_35));

/* SSA %36 in * */
ssa_36 = false;

/* SSA %37 in * */
ssa_37 = a.data.elements[(ssa_35) - 1];

/* SSA %39 in * */
ssa_39 = false;

/* SSA %40 in * */
ssa_40 = b.data.elements[(arg_23) - 1];

/* SSA %41 in * */
ssa_41 = ((ssa_37) * (ssa_40));

/* SSA %145 in * */
ssa_145 = ((arg_24) + (ssa_41));

/* SSA %43 in * */
ssa_43 = ((arg_23) == (12LL));

/* SSA %148 in * */
arg_24 = ssa_145;
}
ssa_148 = (NTuple1_f64){ .elements = { arg_24 } };

/* SSA %29 in * */
ssa_29 = ssa_162;

/* SSA %30 in * */
ssa_30 = ssa_162;

/* SSA %31 in * */
ssa_31 = ssa_148.elements[0];

/* SSA %42 in * */
ssa_42 = ssa_148.elements[0];

/* SSA %55 in * */

/* SSA %163 in * */
uint64_t bitcast_src9;
bitcast_src9 = ((((uint64_t)(12LL))) + (((uint64_t)(1LL))));
// cppcheck-suppress misra-c2012-21.15 ; representation-preserving bitcast
(void)memcpy(&ssa_163, &bitcast_src9, sizeof(ssa_163));

/* SSA %152 in * */
arg_26 = 0.0;
for (arg_25 = 1LL; arg_25 < ssa_163; arg_25 += 1LL) {

/* SSA %60 in * */
uint64_t bitcast_src10;
bitcast_src10 = ((((uint64_t)(arg_25))) - (((uint64_t)(1LL))));
// cppcheck-suppress misra-c2012-21.15 ; representation-preserving bitcast
(void)memcpy(&ssa_60, &bitcast_src10, sizeof(ssa_60));

/* SSA %61 in * */
uint64_t bitcast_src11;
bitcast_src11 = ((((uint64_t)(ssa_60))) * (((uint64_t)(5LL))));
// cppcheck-suppress misra-c2012-21.15 ; representation-preserving bitcast
(void)memcpy(&ssa_61, &bitcast_src11, sizeof(ssa_61));

/* SSA %62 in * */
uint64_t bitcast_src12;
bitcast_src12 = ((((uint64_t)(ssa_61))) + (((uint64_t)(3LL))));
// cppcheck-suppress misra-c2012-21.15 ; representation-preserving bitcast
(void)memcpy(&ssa_62, &bitcast_src12, sizeof(ssa_62));

/* SSA %63 in * */
ssa_63 = false;

/* SSA %64 in * */
ssa_64 = a.data.elements[(ssa_62) - 1];

/* SSA %66 in * */
ssa_66 = false;

/* SSA %67 in * */
ssa_67 = b.data.elements[(arg_25) - 1];

/* SSA %68 in * */
ssa_68 = ((ssa_64) * (ssa_67));

/* SSA %149 in * */
ssa_149 = ((arg_26) + (ssa_68));

/* SSA %70 in * */
ssa_70 = ((arg_25) == (12LL));

/* SSA %152 in * */
arg_26 = ssa_149;
}
ssa_152 = (NTuple1_f64){ .elements = { arg_26 } };

/* SSA %56 in * */
ssa_56 = ssa_163;

/* SSA %57 in * */
ssa_57 = ssa_163;

/* SSA %58 in * */
ssa_58 = ssa_152.elements[0];

/* SSA %69 in * */
ssa_69 = ssa_152.elements[0];

/* SSA %82 in * */

/* SSA %164 in * */
uint64_t bitcast_src13;
bitcast_src13 = ((((uint64_t)(12LL))) + (((uint64_t)(1LL))));
// cppcheck-suppress misra-c2012-21.15 ; representation-preserving bitcast
(void)memcpy(&ssa_164, &bitcast_src13, sizeof(ssa_164));

/* SSA %156 in * */
arg_28 = 0.0;
for (arg_27 = 1LL; arg_27 < ssa_164; arg_27 += 1LL) {

/* SSA %87 in * */
uint64_t bitcast_src14;
bitcast_src14 = ((((uint64_t)(arg_27))) - (((uint64_t)(1LL))));
// cppcheck-suppress misra-c2012-21.15 ; representation-preserving bitcast
(void)memcpy(&ssa_87, &bitcast_src14, sizeof(ssa_87));

/* SSA %88 in * */
uint64_t bitcast_src15;
bitcast_src15 = ((((uint64_t)(ssa_87))) * (((uint64_t)(5LL))));
// cppcheck-suppress misra-c2012-21.15 ; representation-preserving bitcast
(void)memcpy(&ssa_88, &bitcast_src15, sizeof(ssa_88));

/* SSA %89 in * */
uint64_t bitcast_src16;
bitcast_src16 = ((((uint64_t)(ssa_88))) + (((uint64_t)(4LL))));
// cppcheck-suppress misra-c2012-21.15 ; representation-preserving bitcast
(void)memcpy(&ssa_89, &bitcast_src16, sizeof(ssa_89));

/* SSA %90 in * */
ssa_90 = false;

/* SSA %91 in * */
ssa_91 = a.data.elements[(ssa_89) - 1];

/* SSA %93 in * */
ssa_93 = false;

/* SSA %94 in * */
ssa_94 = b.data.elements[(arg_27) - 1];

/* SSA %95 in * */
ssa_95 = ((ssa_91) * (ssa_94));

/* SSA %153 in * */
ssa_153 = ((arg_28) + (ssa_95));

/* SSA %97 in * */
ssa_97 = ((arg_27) == (12LL));

/* SSA %156 in * */
arg_28 = ssa_153;
}
ssa_156 = (NTuple1_f64){ .elements = { arg_28 } };

/* SSA %83 in * */
ssa_83 = ssa_164;

/* SSA %84 in * */
ssa_84 = ssa_164;

/* SSA %85 in * */
ssa_85 = ssa_156.elements[0];

/* SSA %96 in * */
ssa_96 = ssa_156.elements[0];

/* SSA %109 in * */

/* SSA %165 in * */
uint64_t bitcast_src17;
bitcast_src17 = ((((uint64_t)(12LL))) + (((uint64_t)(1LL))));
// cppcheck-suppress misra-c2012-21.15 ; representation-preserving bitcast
(void)memcpy(&ssa_165, &bitcast_src17, sizeof(ssa_165));

/* SSA %160 in * */
arg_30 = 0.0;
for (arg_29 = 1LL; arg_29 < ssa_165; arg_29 += 1LL) {

/* SSA %114 in * */
uint64_t bitcast_src18;
bitcast_src18 = ((((uint64_t)(arg_29))) - (((uint64_t)(1LL))));
// cppcheck-suppress misra-c2012-21.15 ; representation-preserving bitcast
(void)memcpy(&ssa_114, &bitcast_src18, sizeof(ssa_114));

/* SSA %115 in * */
uint64_t bitcast_src19;
bitcast_src19 = ((((uint64_t)(ssa_114))) * (((uint64_t)(5LL))));
// cppcheck-suppress misra-c2012-21.15 ; representation-preserving bitcast
(void)memcpy(&ssa_115, &bitcast_src19, sizeof(ssa_115));

/* SSA %116 in * */
uint64_t bitcast_src20;
bitcast_src20 = ((((uint64_t)(ssa_115))) + (((uint64_t)(5LL))));
// cppcheck-suppress misra-c2012-21.15 ; representation-preserving bitcast
(void)memcpy(&ssa_116, &bitcast_src20, sizeof(ssa_116));

/* SSA %117 in * */
ssa_117 = false;

/* SSA %118 in * */
ssa_118 = a.data.elements[(ssa_116) - 1];

/* SSA %120 in * */
ssa_120 = false;

/* SSA %121 in * */
ssa_121 = b.data.elements[(arg_29) - 1];

/* SSA %122 in * */
ssa_122 = ((ssa_118) * (ssa_121));

/* SSA %157 in * */
ssa_157 = ((arg_30) + (ssa_122));

/* SSA %124 in * */
ssa_124 = ((arg_29) == (12LL));

/* SSA %160 in * */
arg_30 = ssa_157;
}
ssa_160 = (NTuple1_f64){ .elements = { arg_30 } };

/* SSA %110 in * */
ssa_110 = ssa_165;

/* SSA %111 in * */
ssa_111 = ssa_165;

/* SSA %112 in * */
ssa_112 = ssa_160.elements[0];

/* SSA %123 in * */
ssa_123 = ssa_160.elements[0];

/* SSA %136 in * */
ssa_136 = (NTuple5_f64){ .elements = { ssa_15, ssa_42, ssa_69, ssa_96, ssa_123 } };

/* SSA %139 in * */
ssa_139 = (SynchArray_f64x5){ ssa_136 };

/* SSA %140 in * */
// cppcheck-suppress misra-c2012-15.5 ; structured Julia control flow
return ssa_139;
}

/* function +(a::SynchJulia.SynchVector{Float64, 5}, b::SynchJulia.SynchVector{Float64, 5}, c::SynchJulia.SynchVector{Float64, 5}) at operators.jl:653 */
static SynchArray_f64x5 plus_f64x5_f64x5_f64x5(SynchArray_f64x5 a, SynchArray_f64x5 b, SynchArray_f64x5 c) {
bool ssa_2;
double ssa_3;
bool ssa_5;
double ssa_6;
double ssa_7;
bool ssa_9;
double ssa_10;
bool ssa_12;
double ssa_13;
double ssa_14;
bool ssa_16;
double ssa_17;
bool ssa_19;
double ssa_20;
double ssa_21;
bool ssa_23;
double ssa_24;
bool ssa_26;
double ssa_27;
double ssa_28;
bool ssa_30;
double ssa_31;
bool ssa_33;
double ssa_34;
double ssa_35;
bool ssa_37;
double ssa_38;
double ssa_39;
bool ssa_41;
double ssa_42;
double ssa_43;
bool ssa_45;
double ssa_46;
double ssa_47;
bool ssa_49;
double ssa_50;
double ssa_51;
bool ssa_53;
double ssa_54;
double ssa_55;
NTuple5_f64 ssa_56;
SynchArray_f64x5 ssa_57;
/* SSA %2 in + */
ssa_2 = false;

/* SSA %3 in + */
ssa_3 = a.data.elements[0];

/* SSA %5 in + */
ssa_5 = false;

/* SSA %6 in + */
ssa_6 = b.data.elements[0];

/* SSA %7 in + */
ssa_7 = ((ssa_3) + (ssa_6));

/* SSA %9 in + */
ssa_9 = false;

/* SSA %10 in + */
ssa_10 = a.data.elements[1];

/* SSA %12 in + */
ssa_12 = false;

/* SSA %13 in + */
ssa_13 = b.data.elements[1];

/* SSA %14 in + */
ssa_14 = ((ssa_10) + (ssa_13));

/* SSA %16 in + */
ssa_16 = false;

/* SSA %17 in + */
ssa_17 = a.data.elements[2];

/* SSA %19 in + */
ssa_19 = false;

/* SSA %20 in + */
ssa_20 = b.data.elements[2];

/* SSA %21 in + */
ssa_21 = ((ssa_17) + (ssa_20));

/* SSA %23 in + */
ssa_23 = false;

/* SSA %24 in + */
ssa_24 = a.data.elements[3];

/* SSA %26 in + */
ssa_26 = false;

/* SSA %27 in + */
ssa_27 = b.data.elements[3];

/* SSA %28 in + */
ssa_28 = ((ssa_24) + (ssa_27));

/* SSA %30 in + */
ssa_30 = false;

/* SSA %31 in + */
ssa_31 = a.data.elements[4];

/* SSA %33 in + */
ssa_33 = false;

/* SSA %34 in + */
ssa_34 = b.data.elements[4];

/* SSA %35 in + */
ssa_35 = ((ssa_31) + (ssa_34));

/* SSA %37 in + */
ssa_37 = false;

/* SSA %38 in + */
ssa_38 = c.data.elements[0];

/* SSA %39 in + */
ssa_39 = ((ssa_7) + (ssa_38));

/* SSA %41 in + */
ssa_41 = false;

/* SSA %42 in + */
ssa_42 = c.data.elements[1];

/* SSA %43 in + */
ssa_43 = ((ssa_14) + (ssa_42));

/* SSA %45 in + */
ssa_45 = false;

/* SSA %46 in + */
ssa_46 = c.data.elements[2];

/* SSA %47 in + */
ssa_47 = ((ssa_21) + (ssa_46));

/* SSA %49 in + */
ssa_49 = false;

/* SSA %50 in + */
ssa_50 = c.data.elements[3];

/* SSA %51 in + */
ssa_51 = ((ssa_28) + (ssa_50));

/* SSA %53 in + */
ssa_53 = false;

/* SSA %54 in + */
ssa_54 = c.data.elements[4];

/* SSA %55 in + */
ssa_55 = ((ssa_35) + (ssa_54));

/* SSA %56 in + */
ssa_56 = (NTuple5_f64){ .elements = { ssa_39, ssa_43, ssa_47, ssa_51, ssa_55 } };

/* SSA %57 in + */
ssa_57 = (SynchArray_f64x5){ ssa_56 };

/* SSA %58 in + */
// cppcheck-suppress misra-c2012-15.5 ; structured Julia control flow
return ssa_57;
}

/* function *(a::SynchJulia.SynchMatrix{Float64, 12, 12, 144}, b::SynchJulia.SynchVector{Float64, 12}) at /Users/shobhitvoleti/.julia/packages/SynchJulia/Q957d/src/runtime/builtins.jl:271 */
static SynchArray_f64x12 mul_f64x12x12_f64x12(SynchArray_f64x12x12 a, SynchArray_f64x12 b) {
int64_t ssa_378;
int64_t arg_49;
double arg_50;
int64_t ssa_6;
int64_t ssa_7;
int64_t ssa_8;
bool ssa_9;
double ssa_10;
bool ssa_12;
double ssa_13;
double ssa_14;
double ssa_330;
bool ssa_16;
NTuple1_f64 ssa_333;
int64_t ssa_2;
int64_t ssa_3;
double ssa_4;
double ssa_15;
int64_t ssa_379;
int64_t arg_51;
double arg_52;
int64_t ssa_33;
int64_t ssa_34;
int64_t ssa_35;
bool ssa_36;
double ssa_37;
bool ssa_39;
double ssa_40;
double ssa_41;
double ssa_334;
bool ssa_43;
NTuple1_f64 ssa_337;
int64_t ssa_29;
int64_t ssa_30;
double ssa_31;
double ssa_42;
int64_t ssa_380;
int64_t arg_53;
double arg_54;
int64_t ssa_60;
int64_t ssa_61;
int64_t ssa_62;
bool ssa_63;
double ssa_64;
bool ssa_66;
double ssa_67;
double ssa_68;
double ssa_338;
bool ssa_70;
NTuple1_f64 ssa_341;
int64_t ssa_56;
int64_t ssa_57;
double ssa_58;
double ssa_69;
int64_t ssa_381;
int64_t arg_55;
double arg_56;
int64_t ssa_87;
int64_t ssa_88;
int64_t ssa_89;
bool ssa_90;
double ssa_91;
bool ssa_93;
double ssa_94;
double ssa_95;
double ssa_342;
bool ssa_97;
NTuple1_f64 ssa_345;
int64_t ssa_83;
int64_t ssa_84;
double ssa_85;
double ssa_96;
int64_t ssa_382;
int64_t arg_57;
double arg_58;
int64_t ssa_114;
int64_t ssa_115;
int64_t ssa_116;
bool ssa_117;
double ssa_118;
bool ssa_120;
double ssa_121;
double ssa_122;
double ssa_346;
bool ssa_124;
NTuple1_f64 ssa_349;
int64_t ssa_110;
int64_t ssa_111;
double ssa_112;
double ssa_123;
int64_t ssa_383;
int64_t arg_59;
double arg_60;
int64_t ssa_141;
int64_t ssa_142;
int64_t ssa_143;
bool ssa_144;
double ssa_145;
bool ssa_147;
double ssa_148;
double ssa_149;
double ssa_350;
bool ssa_151;
NTuple1_f64 ssa_353;
int64_t ssa_137;
int64_t ssa_138;
double ssa_139;
double ssa_150;
int64_t ssa_384;
int64_t arg_61;
double arg_62;
int64_t ssa_168;
int64_t ssa_169;
int64_t ssa_170;
bool ssa_171;
double ssa_172;
bool ssa_174;
double ssa_175;
double ssa_176;
double ssa_354;
bool ssa_178;
NTuple1_f64 ssa_357;
int64_t ssa_164;
int64_t ssa_165;
double ssa_166;
double ssa_177;
int64_t ssa_385;
int64_t arg_63;
double arg_64;
int64_t ssa_195;
int64_t ssa_196;
int64_t ssa_197;
bool ssa_198;
double ssa_199;
bool ssa_201;
double ssa_202;
double ssa_203;
double ssa_358;
bool ssa_205;
NTuple1_f64 ssa_361;
int64_t ssa_191;
int64_t ssa_192;
double ssa_193;
double ssa_204;
int64_t ssa_386;
int64_t arg_65;
double arg_66;
int64_t ssa_222;
int64_t ssa_223;
int64_t ssa_224;
bool ssa_225;
double ssa_226;
bool ssa_228;
double ssa_229;
double ssa_230;
double ssa_362;
bool ssa_232;
NTuple1_f64 ssa_365;
int64_t ssa_218;
int64_t ssa_219;
double ssa_220;
double ssa_231;
int64_t ssa_387;
int64_t arg_67;
double arg_68;
int64_t ssa_249;
int64_t ssa_250;
int64_t ssa_251;
bool ssa_252;
double ssa_253;
bool ssa_255;
double ssa_256;
double ssa_257;
double ssa_366;
bool ssa_259;
NTuple1_f64 ssa_369;
int64_t ssa_245;
int64_t ssa_246;
double ssa_247;
double ssa_258;
int64_t ssa_388;
int64_t arg_69;
double arg_70;
int64_t ssa_276;
int64_t ssa_277;
int64_t ssa_278;
bool ssa_279;
double ssa_280;
bool ssa_282;
double ssa_283;
double ssa_284;
double ssa_370;
bool ssa_286;
NTuple1_f64 ssa_373;
int64_t ssa_272;
int64_t ssa_273;
double ssa_274;
double ssa_285;
int64_t ssa_389;
int64_t arg_71;
double arg_72;
int64_t ssa_303;
int64_t ssa_304;
int64_t ssa_305;
bool ssa_306;
double ssa_307;
bool ssa_309;
double ssa_310;
double ssa_311;
double ssa_374;
bool ssa_313;
NTuple1_f64 ssa_377;
int64_t ssa_299;
int64_t ssa_300;
double ssa_301;
double ssa_312;
NTuple12_f64 ssa_325;
SynchArray_f64x12 ssa_328;
/* SSA %1 in * */

/* SSA %378 in * */
uint64_t bitcast_src1;
bitcast_src1 = ((((uint64_t)(12LL))) + (((uint64_t)(1LL))));
// cppcheck-suppress misra-c2012-21.15 ; representation-preserving bitcast
(void)memcpy(&ssa_378, &bitcast_src1, sizeof(ssa_378));

/* SSA %333 in * */
arg_50 = 0.0;
for (arg_49 = 1LL; arg_49 < ssa_378; arg_49 += 1LL) {

/* SSA %6 in * */
uint64_t bitcast_src2;
bitcast_src2 = ((((uint64_t)(arg_49))) - (((uint64_t)(1LL))));
// cppcheck-suppress misra-c2012-21.15 ; representation-preserving bitcast
(void)memcpy(&ssa_6, &bitcast_src2, sizeof(ssa_6));

/* SSA %7 in * */
uint64_t bitcast_src3;
bitcast_src3 = ((((uint64_t)(ssa_6))) * (((uint64_t)(12LL))));
// cppcheck-suppress misra-c2012-21.15 ; representation-preserving bitcast
(void)memcpy(&ssa_7, &bitcast_src3, sizeof(ssa_7));

/* SSA %8 in * */
uint64_t bitcast_src4;
bitcast_src4 = ((((uint64_t)(ssa_7))) + (((uint64_t)(1LL))));
// cppcheck-suppress misra-c2012-21.15 ; representation-preserving bitcast
(void)memcpy(&ssa_8, &bitcast_src4, sizeof(ssa_8));

/* SSA %9 in * */
ssa_9 = false;

/* SSA %10 in * */
ssa_10 = a.data.elements[(ssa_8) - 1];

/* SSA %12 in * */
ssa_12 = false;

/* SSA %13 in * */
ssa_13 = b.data.elements[(arg_49) - 1];

/* SSA %14 in * */
ssa_14 = ((ssa_10) * (ssa_13));

/* SSA %330 in * */
ssa_330 = ((arg_50) + (ssa_14));

/* SSA %16 in * */
ssa_16 = ((arg_49) == (12LL));

/* SSA %333 in * */
arg_50 = ssa_330;
}
ssa_333 = (NTuple1_f64){ .elements = { arg_50 } };

/* SSA %2 in * */
ssa_2 = ssa_378;

/* SSA %3 in * */
ssa_3 = ssa_378;

/* SSA %4 in * */
ssa_4 = ssa_333.elements[0];

/* SSA %15 in * */
ssa_15 = ssa_333.elements[0];

/* SSA %28 in * */

/* SSA %379 in * */
uint64_t bitcast_src5;
bitcast_src5 = ((((uint64_t)(12LL))) + (((uint64_t)(1LL))));
// cppcheck-suppress misra-c2012-21.15 ; representation-preserving bitcast
(void)memcpy(&ssa_379, &bitcast_src5, sizeof(ssa_379));

/* SSA %337 in * */
arg_52 = 0.0;
for (arg_51 = 1LL; arg_51 < ssa_379; arg_51 += 1LL) {

/* SSA %33 in * */
uint64_t bitcast_src6;
bitcast_src6 = ((((uint64_t)(arg_51))) - (((uint64_t)(1LL))));
// cppcheck-suppress misra-c2012-21.15 ; representation-preserving bitcast
(void)memcpy(&ssa_33, &bitcast_src6, sizeof(ssa_33));

/* SSA %34 in * */
uint64_t bitcast_src7;
bitcast_src7 = ((((uint64_t)(ssa_33))) * (((uint64_t)(12LL))));
// cppcheck-suppress misra-c2012-21.15 ; representation-preserving bitcast
(void)memcpy(&ssa_34, &bitcast_src7, sizeof(ssa_34));

/* SSA %35 in * */
uint64_t bitcast_src8;
bitcast_src8 = ((((uint64_t)(ssa_34))) + (((uint64_t)(2LL))));
// cppcheck-suppress misra-c2012-21.15 ; representation-preserving bitcast
(void)memcpy(&ssa_35, &bitcast_src8, sizeof(ssa_35));

/* SSA %36 in * */
ssa_36 = false;

/* SSA %37 in * */
ssa_37 = a.data.elements[(ssa_35) - 1];

/* SSA %39 in * */
ssa_39 = false;

/* SSA %40 in * */
ssa_40 = b.data.elements[(arg_51) - 1];

/* SSA %41 in * */
ssa_41 = ((ssa_37) * (ssa_40));

/* SSA %334 in * */
ssa_334 = ((arg_52) + (ssa_41));

/* SSA %43 in * */
ssa_43 = ((arg_51) == (12LL));

/* SSA %337 in * */
arg_52 = ssa_334;
}
ssa_337 = (NTuple1_f64){ .elements = { arg_52 } };

/* SSA %29 in * */
ssa_29 = ssa_379;

/* SSA %30 in * */
ssa_30 = ssa_379;

/* SSA %31 in * */
ssa_31 = ssa_337.elements[0];

/* SSA %42 in * */
ssa_42 = ssa_337.elements[0];

/* SSA %55 in * */

/* SSA %380 in * */
uint64_t bitcast_src9;
bitcast_src9 = ((((uint64_t)(12LL))) + (((uint64_t)(1LL))));
// cppcheck-suppress misra-c2012-21.15 ; representation-preserving bitcast
(void)memcpy(&ssa_380, &bitcast_src9, sizeof(ssa_380));

/* SSA %341 in * */
arg_54 = 0.0;
for (arg_53 = 1LL; arg_53 < ssa_380; arg_53 += 1LL) {

/* SSA %60 in * */
uint64_t bitcast_src10;
bitcast_src10 = ((((uint64_t)(arg_53))) - (((uint64_t)(1LL))));
// cppcheck-suppress misra-c2012-21.15 ; representation-preserving bitcast
(void)memcpy(&ssa_60, &bitcast_src10, sizeof(ssa_60));

/* SSA %61 in * */
uint64_t bitcast_src11;
bitcast_src11 = ((((uint64_t)(ssa_60))) * (((uint64_t)(12LL))));
// cppcheck-suppress misra-c2012-21.15 ; representation-preserving bitcast
(void)memcpy(&ssa_61, &bitcast_src11, sizeof(ssa_61));

/* SSA %62 in * */
uint64_t bitcast_src12;
bitcast_src12 = ((((uint64_t)(ssa_61))) + (((uint64_t)(3LL))));
// cppcheck-suppress misra-c2012-21.15 ; representation-preserving bitcast
(void)memcpy(&ssa_62, &bitcast_src12, sizeof(ssa_62));

/* SSA %63 in * */
ssa_63 = false;

/* SSA %64 in * */
ssa_64 = a.data.elements[(ssa_62) - 1];

/* SSA %66 in * */
ssa_66 = false;

/* SSA %67 in * */
ssa_67 = b.data.elements[(arg_53) - 1];

/* SSA %68 in * */
ssa_68 = ((ssa_64) * (ssa_67));

/* SSA %338 in * */
ssa_338 = ((arg_54) + (ssa_68));

/* SSA %70 in * */
ssa_70 = ((arg_53) == (12LL));

/* SSA %341 in * */
arg_54 = ssa_338;
}
ssa_341 = (NTuple1_f64){ .elements = { arg_54 } };

/* SSA %56 in * */
ssa_56 = ssa_380;

/* SSA %57 in * */
ssa_57 = ssa_380;

/* SSA %58 in * */
ssa_58 = ssa_341.elements[0];

/* SSA %69 in * */
ssa_69 = ssa_341.elements[0];

/* SSA %82 in * */

/* SSA %381 in * */
uint64_t bitcast_src13;
bitcast_src13 = ((((uint64_t)(12LL))) + (((uint64_t)(1LL))));
// cppcheck-suppress misra-c2012-21.15 ; representation-preserving bitcast
(void)memcpy(&ssa_381, &bitcast_src13, sizeof(ssa_381));

/* SSA %345 in * */
arg_56 = 0.0;
for (arg_55 = 1LL; arg_55 < ssa_381; arg_55 += 1LL) {

/* SSA %87 in * */
uint64_t bitcast_src14;
bitcast_src14 = ((((uint64_t)(arg_55))) - (((uint64_t)(1LL))));
// cppcheck-suppress misra-c2012-21.15 ; representation-preserving bitcast
(void)memcpy(&ssa_87, &bitcast_src14, sizeof(ssa_87));

/* SSA %88 in * */
uint64_t bitcast_src15;
bitcast_src15 = ((((uint64_t)(ssa_87))) * (((uint64_t)(12LL))));
// cppcheck-suppress misra-c2012-21.15 ; representation-preserving bitcast
(void)memcpy(&ssa_88, &bitcast_src15, sizeof(ssa_88));

/* SSA %89 in * */
uint64_t bitcast_src16;
bitcast_src16 = ((((uint64_t)(ssa_88))) + (((uint64_t)(4LL))));
// cppcheck-suppress misra-c2012-21.15 ; representation-preserving bitcast
(void)memcpy(&ssa_89, &bitcast_src16, sizeof(ssa_89));

/* SSA %90 in * */
ssa_90 = false;

/* SSA %91 in * */
ssa_91 = a.data.elements[(ssa_89) - 1];

/* SSA %93 in * */
ssa_93 = false;

/* SSA %94 in * */
ssa_94 = b.data.elements[(arg_55) - 1];

/* SSA %95 in * */
ssa_95 = ((ssa_91) * (ssa_94));

/* SSA %342 in * */
ssa_342 = ((arg_56) + (ssa_95));

/* SSA %97 in * */
ssa_97 = ((arg_55) == (12LL));

/* SSA %345 in * */
arg_56 = ssa_342;
}
ssa_345 = (NTuple1_f64){ .elements = { arg_56 } };

/* SSA %83 in * */
ssa_83 = ssa_381;

/* SSA %84 in * */
ssa_84 = ssa_381;

/* SSA %85 in * */
ssa_85 = ssa_345.elements[0];

/* SSA %96 in * */
ssa_96 = ssa_345.elements[0];

/* SSA %109 in * */

/* SSA %382 in * */
uint64_t bitcast_src17;
bitcast_src17 = ((((uint64_t)(12LL))) + (((uint64_t)(1LL))));
// cppcheck-suppress misra-c2012-21.15 ; representation-preserving bitcast
(void)memcpy(&ssa_382, &bitcast_src17, sizeof(ssa_382));

/* SSA %349 in * */
arg_58 = 0.0;
for (arg_57 = 1LL; arg_57 < ssa_382; arg_57 += 1LL) {

/* SSA %114 in * */
uint64_t bitcast_src18;
bitcast_src18 = ((((uint64_t)(arg_57))) - (((uint64_t)(1LL))));
// cppcheck-suppress misra-c2012-21.15 ; representation-preserving bitcast
(void)memcpy(&ssa_114, &bitcast_src18, sizeof(ssa_114));

/* SSA %115 in * */
uint64_t bitcast_src19;
bitcast_src19 = ((((uint64_t)(ssa_114))) * (((uint64_t)(12LL))));
// cppcheck-suppress misra-c2012-21.15 ; representation-preserving bitcast
(void)memcpy(&ssa_115, &bitcast_src19, sizeof(ssa_115));

/* SSA %116 in * */
uint64_t bitcast_src20;
bitcast_src20 = ((((uint64_t)(ssa_115))) + (((uint64_t)(5LL))));
// cppcheck-suppress misra-c2012-21.15 ; representation-preserving bitcast
(void)memcpy(&ssa_116, &bitcast_src20, sizeof(ssa_116));

/* SSA %117 in * */
ssa_117 = false;

/* SSA %118 in * */
ssa_118 = a.data.elements[(ssa_116) - 1];

/* SSA %120 in * */
ssa_120 = false;

/* SSA %121 in * */
ssa_121 = b.data.elements[(arg_57) - 1];

/* SSA %122 in * */
ssa_122 = ((ssa_118) * (ssa_121));

/* SSA %346 in * */
ssa_346 = ((arg_58) + (ssa_122));

/* SSA %124 in * */
ssa_124 = ((arg_57) == (12LL));

/* SSA %349 in * */
arg_58 = ssa_346;
}
ssa_349 = (NTuple1_f64){ .elements = { arg_58 } };

/* SSA %110 in * */
ssa_110 = ssa_382;

/* SSA %111 in * */
ssa_111 = ssa_382;

/* SSA %112 in * */
ssa_112 = ssa_349.elements[0];

/* SSA %123 in * */
ssa_123 = ssa_349.elements[0];

/* SSA %136 in * */

/* SSA %383 in * */
uint64_t bitcast_src21;
bitcast_src21 = ((((uint64_t)(12LL))) + (((uint64_t)(1LL))));
// cppcheck-suppress misra-c2012-21.15 ; representation-preserving bitcast
(void)memcpy(&ssa_383, &bitcast_src21, sizeof(ssa_383));

/* SSA %353 in * */
arg_60 = 0.0;
for (arg_59 = 1LL; arg_59 < ssa_383; arg_59 += 1LL) {

/* SSA %141 in * */
uint64_t bitcast_src22;
bitcast_src22 = ((((uint64_t)(arg_59))) - (((uint64_t)(1LL))));
// cppcheck-suppress misra-c2012-21.15 ; representation-preserving bitcast
(void)memcpy(&ssa_141, &bitcast_src22, sizeof(ssa_141));

/* SSA %142 in * */
uint64_t bitcast_src23;
bitcast_src23 = ((((uint64_t)(ssa_141))) * (((uint64_t)(12LL))));
// cppcheck-suppress misra-c2012-21.15 ; representation-preserving bitcast
(void)memcpy(&ssa_142, &bitcast_src23, sizeof(ssa_142));

/* SSA %143 in * */
uint64_t bitcast_src24;
bitcast_src24 = ((((uint64_t)(ssa_142))) + (((uint64_t)(6LL))));
// cppcheck-suppress misra-c2012-21.15 ; representation-preserving bitcast
(void)memcpy(&ssa_143, &bitcast_src24, sizeof(ssa_143));

/* SSA %144 in * */
ssa_144 = false;

/* SSA %145 in * */
ssa_145 = a.data.elements[(ssa_143) - 1];

/* SSA %147 in * */
ssa_147 = false;

/* SSA %148 in * */
ssa_148 = b.data.elements[(arg_59) - 1];

/* SSA %149 in * */
ssa_149 = ((ssa_145) * (ssa_148));

/* SSA %350 in * */
ssa_350 = ((arg_60) + (ssa_149));

/* SSA %151 in * */
ssa_151 = ((arg_59) == (12LL));

/* SSA %353 in * */
arg_60 = ssa_350;
}
ssa_353 = (NTuple1_f64){ .elements = { arg_60 } };

/* SSA %137 in * */
ssa_137 = ssa_383;

/* SSA %138 in * */
ssa_138 = ssa_383;

/* SSA %139 in * */
ssa_139 = ssa_353.elements[0];

/* SSA %150 in * */
ssa_150 = ssa_353.elements[0];

/* SSA %163 in * */

/* SSA %384 in * */
uint64_t bitcast_src25;
bitcast_src25 = ((((uint64_t)(12LL))) + (((uint64_t)(1LL))));
// cppcheck-suppress misra-c2012-21.15 ; representation-preserving bitcast
(void)memcpy(&ssa_384, &bitcast_src25, sizeof(ssa_384));

/* SSA %357 in * */
arg_62 = 0.0;
for (arg_61 = 1LL; arg_61 < ssa_384; arg_61 += 1LL) {

/* SSA %168 in * */
uint64_t bitcast_src26;
bitcast_src26 = ((((uint64_t)(arg_61))) - (((uint64_t)(1LL))));
// cppcheck-suppress misra-c2012-21.15 ; representation-preserving bitcast
(void)memcpy(&ssa_168, &bitcast_src26, sizeof(ssa_168));

/* SSA %169 in * */
uint64_t bitcast_src27;
bitcast_src27 = ((((uint64_t)(ssa_168))) * (((uint64_t)(12LL))));
// cppcheck-suppress misra-c2012-21.15 ; representation-preserving bitcast
(void)memcpy(&ssa_169, &bitcast_src27, sizeof(ssa_169));

/* SSA %170 in * */
uint64_t bitcast_src28;
bitcast_src28 = ((((uint64_t)(ssa_169))) + (((uint64_t)(7LL))));
// cppcheck-suppress misra-c2012-21.15 ; representation-preserving bitcast
(void)memcpy(&ssa_170, &bitcast_src28, sizeof(ssa_170));

/* SSA %171 in * */
ssa_171 = false;

/* SSA %172 in * */
ssa_172 = a.data.elements[(ssa_170) - 1];

/* SSA %174 in * */
ssa_174 = false;

/* SSA %175 in * */
ssa_175 = b.data.elements[(arg_61) - 1];

/* SSA %176 in * */
ssa_176 = ((ssa_172) * (ssa_175));

/* SSA %354 in * */
ssa_354 = ((arg_62) + (ssa_176));

/* SSA %178 in * */
ssa_178 = ((arg_61) == (12LL));

/* SSA %357 in * */
arg_62 = ssa_354;
}
ssa_357 = (NTuple1_f64){ .elements = { arg_62 } };

/* SSA %164 in * */
ssa_164 = ssa_384;

/* SSA %165 in * */
ssa_165 = ssa_384;

/* SSA %166 in * */
ssa_166 = ssa_357.elements[0];

/* SSA %177 in * */
ssa_177 = ssa_357.elements[0];

/* SSA %190 in * */

/* SSA %385 in * */
uint64_t bitcast_src29;
bitcast_src29 = ((((uint64_t)(12LL))) + (((uint64_t)(1LL))));
// cppcheck-suppress misra-c2012-21.15 ; representation-preserving bitcast
(void)memcpy(&ssa_385, &bitcast_src29, sizeof(ssa_385));

/* SSA %361 in * */
arg_64 = 0.0;
for (arg_63 = 1LL; arg_63 < ssa_385; arg_63 += 1LL) {

/* SSA %195 in * */
uint64_t bitcast_src30;
bitcast_src30 = ((((uint64_t)(arg_63))) - (((uint64_t)(1LL))));
// cppcheck-suppress misra-c2012-21.15 ; representation-preserving bitcast
(void)memcpy(&ssa_195, &bitcast_src30, sizeof(ssa_195));

/* SSA %196 in * */
uint64_t bitcast_src31;
bitcast_src31 = ((((uint64_t)(ssa_195))) * (((uint64_t)(12LL))));
// cppcheck-suppress misra-c2012-21.15 ; representation-preserving bitcast
(void)memcpy(&ssa_196, &bitcast_src31, sizeof(ssa_196));

/* SSA %197 in * */
uint64_t bitcast_src32;
bitcast_src32 = ((((uint64_t)(ssa_196))) + (((uint64_t)(8LL))));
// cppcheck-suppress misra-c2012-21.15 ; representation-preserving bitcast
(void)memcpy(&ssa_197, &bitcast_src32, sizeof(ssa_197));

/* SSA %198 in * */
ssa_198 = false;

/* SSA %199 in * */
ssa_199 = a.data.elements[(ssa_197) - 1];

/* SSA %201 in * */
ssa_201 = false;

/* SSA %202 in * */
ssa_202 = b.data.elements[(arg_63) - 1];

/* SSA %203 in * */
ssa_203 = ((ssa_199) * (ssa_202));

/* SSA %358 in * */
ssa_358 = ((arg_64) + (ssa_203));

/* SSA %205 in * */
ssa_205 = ((arg_63) == (12LL));

/* SSA %361 in * */
arg_64 = ssa_358;
}
ssa_361 = (NTuple1_f64){ .elements = { arg_64 } };

/* SSA %191 in * */
ssa_191 = ssa_385;

/* SSA %192 in * */
ssa_192 = ssa_385;

/* SSA %193 in * */
ssa_193 = ssa_361.elements[0];

/* SSA %204 in * */
ssa_204 = ssa_361.elements[0];

/* SSA %217 in * */

/* SSA %386 in * */
uint64_t bitcast_src33;
bitcast_src33 = ((((uint64_t)(12LL))) + (((uint64_t)(1LL))));
// cppcheck-suppress misra-c2012-21.15 ; representation-preserving bitcast
(void)memcpy(&ssa_386, &bitcast_src33, sizeof(ssa_386));

/* SSA %365 in * */
arg_66 = 0.0;
for (arg_65 = 1LL; arg_65 < ssa_386; arg_65 += 1LL) {

/* SSA %222 in * */
uint64_t bitcast_src34;
bitcast_src34 = ((((uint64_t)(arg_65))) - (((uint64_t)(1LL))));
// cppcheck-suppress misra-c2012-21.15 ; representation-preserving bitcast
(void)memcpy(&ssa_222, &bitcast_src34, sizeof(ssa_222));

/* SSA %223 in * */
uint64_t bitcast_src35;
bitcast_src35 = ((((uint64_t)(ssa_222))) * (((uint64_t)(12LL))));
// cppcheck-suppress misra-c2012-21.15 ; representation-preserving bitcast
(void)memcpy(&ssa_223, &bitcast_src35, sizeof(ssa_223));

/* SSA %224 in * */
uint64_t bitcast_src36;
bitcast_src36 = ((((uint64_t)(ssa_223))) + (((uint64_t)(9LL))));
// cppcheck-suppress misra-c2012-21.15 ; representation-preserving bitcast
(void)memcpy(&ssa_224, &bitcast_src36, sizeof(ssa_224));

/* SSA %225 in * */
ssa_225 = false;

/* SSA %226 in * */
ssa_226 = a.data.elements[(ssa_224) - 1];

/* SSA %228 in * */
ssa_228 = false;

/* SSA %229 in * */
ssa_229 = b.data.elements[(arg_65) - 1];

/* SSA %230 in * */
ssa_230 = ((ssa_226) * (ssa_229));

/* SSA %362 in * */
ssa_362 = ((arg_66) + (ssa_230));

/* SSA %232 in * */
ssa_232 = ((arg_65) == (12LL));

/* SSA %365 in * */
arg_66 = ssa_362;
}
ssa_365 = (NTuple1_f64){ .elements = { arg_66 } };

/* SSA %218 in * */
ssa_218 = ssa_386;

/* SSA %219 in * */
ssa_219 = ssa_386;

/* SSA %220 in * */
ssa_220 = ssa_365.elements[0];

/* SSA %231 in * */
ssa_231 = ssa_365.elements[0];

/* SSA %244 in * */

/* SSA %387 in * */
uint64_t bitcast_src37;
bitcast_src37 = ((((uint64_t)(12LL))) + (((uint64_t)(1LL))));
// cppcheck-suppress misra-c2012-21.15 ; representation-preserving bitcast
(void)memcpy(&ssa_387, &bitcast_src37, sizeof(ssa_387));

/* SSA %369 in * */
arg_68 = 0.0;
for (arg_67 = 1LL; arg_67 < ssa_387; arg_67 += 1LL) {

/* SSA %249 in * */
uint64_t bitcast_src38;
bitcast_src38 = ((((uint64_t)(arg_67))) - (((uint64_t)(1LL))));
// cppcheck-suppress misra-c2012-21.15 ; representation-preserving bitcast
(void)memcpy(&ssa_249, &bitcast_src38, sizeof(ssa_249));

/* SSA %250 in * */
uint64_t bitcast_src39;
bitcast_src39 = ((((uint64_t)(ssa_249))) * (((uint64_t)(12LL))));
// cppcheck-suppress misra-c2012-21.15 ; representation-preserving bitcast
(void)memcpy(&ssa_250, &bitcast_src39, sizeof(ssa_250));

/* SSA %251 in * */
uint64_t bitcast_src40;
bitcast_src40 = ((((uint64_t)(ssa_250))) + (((uint64_t)(10LL))));
// cppcheck-suppress misra-c2012-21.15 ; representation-preserving bitcast
(void)memcpy(&ssa_251, &bitcast_src40, sizeof(ssa_251));

/* SSA %252 in * */
ssa_252 = false;

/* SSA %253 in * */
ssa_253 = a.data.elements[(ssa_251) - 1];

/* SSA %255 in * */
ssa_255 = false;

/* SSA %256 in * */
ssa_256 = b.data.elements[(arg_67) - 1];

/* SSA %257 in * */
ssa_257 = ((ssa_253) * (ssa_256));

/* SSA %366 in * */
ssa_366 = ((arg_68) + (ssa_257));

/* SSA %259 in * */
ssa_259 = ((arg_67) == (12LL));

/* SSA %369 in * */
arg_68 = ssa_366;
}
ssa_369 = (NTuple1_f64){ .elements = { arg_68 } };

/* SSA %245 in * */
ssa_245 = ssa_387;

/* SSA %246 in * */
ssa_246 = ssa_387;

/* SSA %247 in * */
ssa_247 = ssa_369.elements[0];

/* SSA %258 in * */
ssa_258 = ssa_369.elements[0];

/* SSA %271 in * */

/* SSA %388 in * */
uint64_t bitcast_src41;
bitcast_src41 = ((((uint64_t)(12LL))) + (((uint64_t)(1LL))));
// cppcheck-suppress misra-c2012-21.15 ; representation-preserving bitcast
(void)memcpy(&ssa_388, &bitcast_src41, sizeof(ssa_388));

/* SSA %373 in * */
arg_70 = 0.0;
for (arg_69 = 1LL; arg_69 < ssa_388; arg_69 += 1LL) {

/* SSA %276 in * */
uint64_t bitcast_src42;
bitcast_src42 = ((((uint64_t)(arg_69))) - (((uint64_t)(1LL))));
// cppcheck-suppress misra-c2012-21.15 ; representation-preserving bitcast
(void)memcpy(&ssa_276, &bitcast_src42, sizeof(ssa_276));

/* SSA %277 in * */
uint64_t bitcast_src43;
bitcast_src43 = ((((uint64_t)(ssa_276))) * (((uint64_t)(12LL))));
// cppcheck-suppress misra-c2012-21.15 ; representation-preserving bitcast
(void)memcpy(&ssa_277, &bitcast_src43, sizeof(ssa_277));

/* SSA %278 in * */
uint64_t bitcast_src44;
bitcast_src44 = ((((uint64_t)(ssa_277))) + (((uint64_t)(11LL))));
// cppcheck-suppress misra-c2012-21.15 ; representation-preserving bitcast
(void)memcpy(&ssa_278, &bitcast_src44, sizeof(ssa_278));

/* SSA %279 in * */
ssa_279 = false;

/* SSA %280 in * */
ssa_280 = a.data.elements[(ssa_278) - 1];

/* SSA %282 in * */
ssa_282 = false;

/* SSA %283 in * */
ssa_283 = b.data.elements[(arg_69) - 1];

/* SSA %284 in * */
ssa_284 = ((ssa_280) * (ssa_283));

/* SSA %370 in * */
ssa_370 = ((arg_70) + (ssa_284));

/* SSA %286 in * */
ssa_286 = ((arg_69) == (12LL));

/* SSA %373 in * */
arg_70 = ssa_370;
}
ssa_373 = (NTuple1_f64){ .elements = { arg_70 } };

/* SSA %272 in * */
ssa_272 = ssa_388;

/* SSA %273 in * */
ssa_273 = ssa_388;

/* SSA %274 in * */
ssa_274 = ssa_373.elements[0];

/* SSA %285 in * */
ssa_285 = ssa_373.elements[0];

/* SSA %298 in * */

/* SSA %389 in * */
uint64_t bitcast_src45;
bitcast_src45 = ((((uint64_t)(12LL))) + (((uint64_t)(1LL))));
// cppcheck-suppress misra-c2012-21.15 ; representation-preserving bitcast
(void)memcpy(&ssa_389, &bitcast_src45, sizeof(ssa_389));

/* SSA %377 in * */
arg_72 = 0.0;
for (arg_71 = 1LL; arg_71 < ssa_389; arg_71 += 1LL) {

/* SSA %303 in * */
uint64_t bitcast_src46;
bitcast_src46 = ((((uint64_t)(arg_71))) - (((uint64_t)(1LL))));
// cppcheck-suppress misra-c2012-21.15 ; representation-preserving bitcast
(void)memcpy(&ssa_303, &bitcast_src46, sizeof(ssa_303));

/* SSA %304 in * */
uint64_t bitcast_src47;
bitcast_src47 = ((((uint64_t)(ssa_303))) * (((uint64_t)(12LL))));
// cppcheck-suppress misra-c2012-21.15 ; representation-preserving bitcast
(void)memcpy(&ssa_304, &bitcast_src47, sizeof(ssa_304));

/* SSA %305 in * */
uint64_t bitcast_src48;
bitcast_src48 = ((((uint64_t)(ssa_304))) + (((uint64_t)(12LL))));
// cppcheck-suppress misra-c2012-21.15 ; representation-preserving bitcast
(void)memcpy(&ssa_305, &bitcast_src48, sizeof(ssa_305));

/* SSA %306 in * */
ssa_306 = false;

/* SSA %307 in * */
ssa_307 = a.data.elements[(ssa_305) - 1];

/* SSA %309 in * */
ssa_309 = false;

/* SSA %310 in * */
ssa_310 = b.data.elements[(arg_71) - 1];

/* SSA %311 in * */
ssa_311 = ((ssa_307) * (ssa_310));

/* SSA %374 in * */
ssa_374 = ((arg_72) + (ssa_311));

/* SSA %313 in * */
ssa_313 = ((arg_71) == (12LL));

/* SSA %377 in * */
arg_72 = ssa_374;
}
ssa_377 = (NTuple1_f64){ .elements = { arg_72 } };

/* SSA %299 in * */
ssa_299 = ssa_389;

/* SSA %300 in * */
ssa_300 = ssa_389;

/* SSA %301 in * */
ssa_301 = ssa_377.elements[0];

/* SSA %312 in * */
ssa_312 = ssa_377.elements[0];

/* SSA %325 in * */
ssa_325 = (NTuple12_f64){ .elements = { ssa_15, ssa_42, ssa_69, ssa_96, ssa_123, ssa_150, ssa_177, ssa_204, ssa_231, ssa_258, ssa_285, ssa_312 } };

/* SSA %328 in * */
ssa_328 = (SynchArray_f64x12){ ssa_325 };

/* SSA %329 in * */
// cppcheck-suppress misra-c2012-15.5 ; structured Julia control flow
return ssa_328;
}

/* function +(a::SynchJulia.SynchVector{Float64, 12}, b::SynchJulia.SynchVector{Float64, 12}) at /Users/shobhitvoleti/.julia/packages/SynchJulia/Q957d/src/runtime/builtins.jl:299 */
static SynchArray_f64x12 plus_f64x12_f64x12(SynchArray_f64x12 a, SynchArray_f64x12 b) {
bool ssa_2;
double ssa_3;
bool ssa_5;
double ssa_6;
double ssa_7;
bool ssa_9;
double ssa_10;
bool ssa_12;
double ssa_13;
double ssa_14;
bool ssa_16;
double ssa_17;
bool ssa_19;
double ssa_20;
double ssa_21;
bool ssa_23;
double ssa_24;
bool ssa_26;
double ssa_27;
double ssa_28;
bool ssa_30;
double ssa_31;
bool ssa_33;
double ssa_34;
double ssa_35;
bool ssa_37;
double ssa_38;
bool ssa_40;
double ssa_41;
double ssa_42;
bool ssa_44;
double ssa_45;
bool ssa_47;
double ssa_48;
double ssa_49;
bool ssa_51;
double ssa_52;
bool ssa_54;
double ssa_55;
double ssa_56;
bool ssa_58;
double ssa_59;
bool ssa_61;
double ssa_62;
double ssa_63;
bool ssa_65;
double ssa_66;
bool ssa_68;
double ssa_69;
double ssa_70;
bool ssa_72;
double ssa_73;
bool ssa_75;
double ssa_76;
double ssa_77;
bool ssa_79;
double ssa_80;
bool ssa_82;
double ssa_83;
double ssa_84;
NTuple12_f64 ssa_85;
SynchArray_f64x12 ssa_86;
/* SSA %2 in + */
ssa_2 = false;

/* SSA %3 in + */
ssa_3 = a.data.elements[0];

/* SSA %5 in + */
ssa_5 = false;

/* SSA %6 in + */
ssa_6 = b.data.elements[0];

/* SSA %7 in + */
ssa_7 = ((ssa_3) + (ssa_6));

/* SSA %9 in + */
ssa_9 = false;

/* SSA %10 in + */
ssa_10 = a.data.elements[1];

/* SSA %12 in + */
ssa_12 = false;

/* SSA %13 in + */
ssa_13 = b.data.elements[1];

/* SSA %14 in + */
ssa_14 = ((ssa_10) + (ssa_13));

/* SSA %16 in + */
ssa_16 = false;

/* SSA %17 in + */
ssa_17 = a.data.elements[2];

/* SSA %19 in + */
ssa_19 = false;

/* SSA %20 in + */
ssa_20 = b.data.elements[2];

/* SSA %21 in + */
ssa_21 = ((ssa_17) + (ssa_20));

/* SSA %23 in + */
ssa_23 = false;

/* SSA %24 in + */
ssa_24 = a.data.elements[3];

/* SSA %26 in + */
ssa_26 = false;

/* SSA %27 in + */
ssa_27 = b.data.elements[3];

/* SSA %28 in + */
ssa_28 = ((ssa_24) + (ssa_27));

/* SSA %30 in + */
ssa_30 = false;

/* SSA %31 in + */
ssa_31 = a.data.elements[4];

/* SSA %33 in + */
ssa_33 = false;

/* SSA %34 in + */
ssa_34 = b.data.elements[4];

/* SSA %35 in + */
ssa_35 = ((ssa_31) + (ssa_34));

/* SSA %37 in + */
ssa_37 = false;

/* SSA %38 in + */
ssa_38 = a.data.elements[5];

/* SSA %40 in + */
ssa_40 = false;

/* SSA %41 in + */
ssa_41 = b.data.elements[5];

/* SSA %42 in + */
ssa_42 = ((ssa_38) + (ssa_41));

/* SSA %44 in + */
ssa_44 = false;

/* SSA %45 in + */
ssa_45 = a.data.elements[6];

/* SSA %47 in + */
ssa_47 = false;

/* SSA %48 in + */
ssa_48 = b.data.elements[6];

/* SSA %49 in + */
ssa_49 = ((ssa_45) + (ssa_48));

/* SSA %51 in + */
ssa_51 = false;

/* SSA %52 in + */
ssa_52 = a.data.elements[7];

/* SSA %54 in + */
ssa_54 = false;

/* SSA %55 in + */
ssa_55 = b.data.elements[7];

/* SSA %56 in + */
ssa_56 = ((ssa_52) + (ssa_55));

/* SSA %58 in + */
ssa_58 = false;

/* SSA %59 in + */
ssa_59 = a.data.elements[8];

/* SSA %61 in + */
ssa_61 = false;

/* SSA %62 in + */
ssa_62 = b.data.elements[8];

/* SSA %63 in + */
ssa_63 = ((ssa_59) + (ssa_62));

/* SSA %65 in + */
ssa_65 = false;

/* SSA %66 in + */
ssa_66 = a.data.elements[9];

/* SSA %68 in + */
ssa_68 = false;

/* SSA %69 in + */
ssa_69 = b.data.elements[9];

/* SSA %70 in + */
ssa_70 = ((ssa_66) + (ssa_69));

/* SSA %72 in + */
ssa_72 = false;

/* SSA %73 in + */
ssa_73 = a.data.elements[10];

/* SSA %75 in + */
ssa_75 = false;

/* SSA %76 in + */
ssa_76 = b.data.elements[10];

/* SSA %77 in + */
ssa_77 = ((ssa_73) + (ssa_76));

/* SSA %79 in + */
ssa_79 = false;

/* SSA %80 in + */
ssa_80 = a.data.elements[11];

/* SSA %82 in + */
ssa_82 = false;

/* SSA %83 in + */
ssa_83 = b.data.elements[11];

/* SSA %84 in + */
ssa_84 = ((ssa_80) + (ssa_83));

/* SSA %85 in + */
ssa_85 = (NTuple12_f64){ .elements = { ssa_7, ssa_14, ssa_21, ssa_28, ssa_35, ssa_42, ssa_49, ssa_56, ssa_63, ssa_70, ssa_77, ssa_84 } };

/* SSA %86 in + */
ssa_86 = (SynchArray_f64x12){ ssa_85 };

/* SSA %87 in + */
// cppcheck-suppress misra-c2012-15.5 ; structured Julia control flow
return ssa_86;
}

/* function getindex(a::SynchJulia.SynchVector{Float64, 12}, i::Int64) at /Users/shobhitvoleti/.julia/packages/SynchJulia/Q957d/src/runtime/array.jl:132 */
static double getindex_f64x12_i64_081010bd(SynchArray_f64x12 a, int64_t i) {
bool ssa_1;
bool ssa_5;
double ssa_6;
(void)i;
/* SSA %1 in getindex */
ssa_1 = true;

/* SSA %8 in getindex */
if (ssa_1) {

/* SSA %3 in getindex */
}

/* SSA %5 in getindex */
ssa_5 = false;

/* SSA %6 in getindex */
ssa_6 = a.data.elements[11];

/* SSA %7 in getindex */
// cppcheck-suppress misra-c2012-15.5 ; structured Julia control flow
return ssa_6;
}

/* function getindex(a::SynchJulia.SynchVector{Float64, 12}, i::Int64) at /Users/shobhitvoleti/.julia/packages/SynchJulia/Q957d/src/runtime/array.jl:132 */
static double getindex_f64x12_i64_e4285bab(SynchArray_f64x12 a, int64_t i) {
bool ssa_1;
bool ssa_5;
double ssa_6;
(void)i;
/* SSA %1 in getindex */
ssa_1 = true;

/* SSA %8 in getindex */
if (ssa_1) {

/* SSA %3 in getindex */
}

/* SSA %5 in getindex */
ssa_5 = false;

/* SSA %6 in getindex */
ssa_6 = a.data.elements[10];

/* SSA %7 in getindex */
// cppcheck-suppress misra-c2012-15.5 ; structured Julia control flow
return ssa_6;
}

/* function getindex(a::SynchJulia.SynchVector{Float64, 12}, i::Int64) at /Users/shobhitvoleti/.julia/packages/SynchJulia/Q957d/src/runtime/array.jl:132 */
static double getindex_f64x12_i64_5879170b(SynchArray_f64x12 a, int64_t i) {
bool ssa_1;
bool ssa_5;
double ssa_6;
(void)i;
/* SSA %1 in getindex */
ssa_1 = true;

/* SSA %8 in getindex */
if (ssa_1) {

/* SSA %3 in getindex */
}

/* SSA %5 in getindex */
ssa_5 = false;

/* SSA %6 in getindex */
ssa_6 = a.data.elements[9];

/* SSA %7 in getindex */
// cppcheck-suppress misra-c2012-15.5 ; structured Julia control flow
return ssa_6;
}

/* function getindex(a::SynchJulia.SynchVector{Float64, 12}, i::Int64) at /Users/shobhitvoleti/.julia/packages/SynchJulia/Q957d/src/runtime/array.jl:132 */
static double getindex_f64x12_i64_adc09d26(SynchArray_f64x12 a, int64_t i) {
bool ssa_1;
bool ssa_5;
double ssa_6;
(void)i;
/* SSA %1 in getindex */
ssa_1 = true;

/* SSA %8 in getindex */
if (ssa_1) {

/* SSA %3 in getindex */
}

/* SSA %5 in getindex */
ssa_5 = false;

/* SSA %6 in getindex */
ssa_6 = a.data.elements[8];

/* SSA %7 in getindex */
// cppcheck-suppress misra-c2012-15.5 ; structured Julia control flow
return ssa_6;
}

/* function getindex(a::SynchJulia.SynchVector{Float64, 12}, i::Int64) at /Users/shobhitvoleti/.julia/packages/SynchJulia/Q957d/src/runtime/array.jl:132 */
static double getindex_f64x12_i64_c29abda5(SynchArray_f64x12 a, int64_t i) {
bool ssa_1;
bool ssa_5;
double ssa_6;
(void)i;
/* SSA %1 in getindex */
ssa_1 = true;

/* SSA %8 in getindex */
if (ssa_1) {

/* SSA %3 in getindex */
}

/* SSA %5 in getindex */
ssa_5 = false;

/* SSA %6 in getindex */
ssa_6 = a.data.elements[7];

/* SSA %7 in getindex */
// cppcheck-suppress misra-c2012-15.5 ; structured Julia control flow
return ssa_6;
}

/* function getindex(a::SynchJulia.SynchVector{Float64, 12}, i::Int64) at /Users/shobhitvoleti/.julia/packages/SynchJulia/Q957d/src/runtime/array.jl:132 */
static double getindex_f64x12_i64_798c8438(SynchArray_f64x12 a, int64_t i) {
bool ssa_1;
bool ssa_5;
double ssa_6;
(void)i;
/* SSA %1 in getindex */
ssa_1 = true;

/* SSA %8 in getindex */
if (ssa_1) {

/* SSA %3 in getindex */
}

/* SSA %5 in getindex */
ssa_5 = false;

/* SSA %6 in getindex */
ssa_6 = a.data.elements[6];

/* SSA %7 in getindex */
// cppcheck-suppress misra-c2012-15.5 ; structured Julia control flow
return ssa_6;
}

/* function getindex(a::SynchJulia.SynchVector{Float64, 12}, i::Int64) at /Users/shobhitvoleti/.julia/packages/SynchJulia/Q957d/src/runtime/array.jl:132 */
static double getindex_f64x12_i64_36f60a18(SynchArray_f64x12 a, int64_t i) {
bool ssa_1;
bool ssa_5;
double ssa_6;
(void)i;
/* SSA %1 in getindex */
ssa_1 = true;

/* SSA %8 in getindex */
if (ssa_1) {

/* SSA %3 in getindex */
}

/* SSA %5 in getindex */
ssa_5 = false;

/* SSA %6 in getindex */
ssa_6 = a.data.elements[5];

/* SSA %7 in getindex */
// cppcheck-suppress misra-c2012-15.5 ; structured Julia control flow
return ssa_6;
}

/* function getindex(a::SynchJulia.SynchVector{Float64, 12}, i::Int64) at /Users/shobhitvoleti/.julia/packages/SynchJulia/Q957d/src/runtime/array.jl:132 */
static double getindex_f64x12_i64_70864f0d(SynchArray_f64x12 a, int64_t i) {
bool ssa_1;
bool ssa_5;
double ssa_6;
(void)i;
/* SSA %1 in getindex */
ssa_1 = true;

/* SSA %8 in getindex */
if (ssa_1) {

/* SSA %3 in getindex */
}

/* SSA %5 in getindex */
ssa_5 = false;

/* SSA %6 in getindex */
ssa_6 = a.data.elements[4];

/* SSA %7 in getindex */
// cppcheck-suppress misra-c2012-15.5 ; structured Julia control flow
return ssa_6;
}

/* function getindex(a::SynchJulia.SynchVector{Float64, 12}, i::Int64) at /Users/shobhitvoleti/.julia/packages/SynchJulia/Q957d/src/runtime/array.jl:132 */
static double getindex_f64x12_i64_8a6206c2(SynchArray_f64x12 a, int64_t i) {
bool ssa_1;
bool ssa_5;
double ssa_6;
(void)i;
/* SSA %1 in getindex */
ssa_1 = true;

/* SSA %8 in getindex */
if (ssa_1) {

/* SSA %3 in getindex */
}

/* SSA %5 in getindex */
ssa_5 = false;

/* SSA %6 in getindex */
ssa_6 = a.data.elements[3];

/* SSA %7 in getindex */
// cppcheck-suppress misra-c2012-15.5 ; structured Julia control flow
return ssa_6;
}

/* function getindex(a::SynchJulia.SynchVector{Float64, 12}, i::Int64) at /Users/shobhitvoleti/.julia/packages/SynchJulia/Q957d/src/runtime/array.jl:132 */
static double getindex_f64x12_i64_9cb6e4c6(SynchArray_f64x12 a, int64_t i) {
bool ssa_1;
bool ssa_5;
double ssa_6;
(void)i;
/* SSA %1 in getindex */
ssa_1 = true;

/* SSA %8 in getindex */
if (ssa_1) {

/* SSA %3 in getindex */
}

/* SSA %5 in getindex */
ssa_5 = false;

/* SSA %6 in getindex */
ssa_6 = a.data.elements[2];

/* SSA %7 in getindex */
// cppcheck-suppress misra-c2012-15.5 ; structured Julia control flow
return ssa_6;
}

/* function getindex(a::SynchJulia.SynchVector{Float64, 12}, i::Int64) at /Users/shobhitvoleti/.julia/packages/SynchJulia/Q957d/src/runtime/array.jl:132 */
static double getindex_f64x12_i64_f1365eec(SynchArray_f64x12 a, int64_t i) {
bool ssa_1;
bool ssa_5;
double ssa_6;
(void)i;
/* SSA %1 in getindex */
ssa_1 = true;

/* SSA %8 in getindex */
if (ssa_1) {

/* SSA %3 in getindex */
}

/* SSA %5 in getindex */
ssa_5 = false;

/* SSA %6 in getindex */
ssa_6 = a.data.elements[1];

/* SSA %7 in getindex */
// cppcheck-suppress misra-c2012-15.5 ; structured Julia control flow
return ssa_6;
}

/* function getindex(a::SynchJulia.SynchVector{Float64, 12}, i::Int64) at /Users/shobhitvoleti/.julia/packages/SynchJulia/Q957d/src/runtime/array.jl:132 */
static double getindex_f64x12_i64_28cdea89(SynchArray_f64x12 a, int64_t i) {
bool ssa_1;
bool ssa_5;
double ssa_6;
(void)i;
/* SSA %1 in getindex */
ssa_1 = true;

/* SSA %8 in getindex */
if (ssa_1) {

/* SSA %3 in getindex */
}

/* SSA %5 in getindex */
ssa_5 = false;

/* SSA %6 in getindex */
ssa_6 = a.data.elements[0];

/* SSA %7 in getindex */
// cppcheck-suppress misra-c2012-15.5 ; structured Julia control flow
return ssa_6;
}

/* function vcat(args_1::Float64, args_2::Float64, args_3::Float64, args_4::Float64, args_5::Float64, args_6::Float64, args_7::Float64, args_8::Float64, args_9::Float64, args_10::Float64, args_11::Float64, args_12::Float64) at /Users/shobhitvoleti/.julia/packages/SynchJulia/Q957d/src/runtime/builtins.jl:54 */
static SynchArray_f64x12 vcat_f64_f64_f64_f64_f64_f64_f64_f64_f64_f64_f64_f64(double args_1, double args_2, double args_3, double args_4, double args_5, double args_6, double args_7, double args_8, double args_9, double args_10, double args_11, double args_12) {
SynchArray_f64x12 ssa_1;
/* SSA %1 in vcat */
ssa_1 = (SynchArray_f64x12){ (NTuple12_f64){ .elements = { args_1, args_2, args_3, args_4, args_5, args_6, args_7, args_8, args_9, args_10, args_11, args_12 } } };

/* SSA %2 in vcat */
// cppcheck-suppress misra-c2012-15.5 ; structured Julia control flow
return ssa_1;
}

/* @node top((u(t))[1:12]::SynchJulia.SynchVector{Float64, 12}, clock1::Bool, pars::SynchToolkit.var"##SynchRuntime#751".Pars) at /Users/shobhitvoleti/.julia/packages/SynchToolkit/FUnNU/src/runtime_compiled.jl:76 */
// cppcheck-suppress-begin misra-c2012-8.7 ; exported entry point
top_f64x12_bool_Pars_out top_f64x12_bool_Pars_step(SynchArray_f64x12 u28_u_u28_t_u29_u29_u5b_1_colon_12_u5d, bool clock1, Pars * pars, top_f64x12_bool_Pars_mem* self) {
SynchArray_f64x12 controller_x_u28_t_u29_2;
bool first_tick_3;
double clock_y_u28_t_u29;
SynchArray_f64x12 controller_u_u28_t_u29;
SynchArray_f64x12 anon_1;
SynchArray_f64x12 controller_x_u28_t_u29_SYNshiftn1;
SynchArray_f64x12 controller_x_u28_t_u29;
SynchArray_f64x5 controller_y_u28_t_u29;
SynchArray_f64x5 u28_y_u28_t_u29_u29_u5b_1_colon_5_u5d = { 0 };
/* equation controller₊x(t)@2 = pre(controller₊x(t)) */
controller_x_u28_t_u29_2 = self->controller_x_u28_t_u29;

/* equation first_tick@3 = pre(false; init=true) */
first_tick_3 = self->first_tick_3;

/* equation clock₊y(t) = getindex((u(t))[1:12], 1) */
if (clock1) {
clock_y_u28_t_u29 = getindex_f64x12_i64_28cdea89(u28_u_u28_t_u29_u29_u5b_1_colon_12_u5d, 1LL);

/* equation controller₊u(t) = vcat(getindex((u(t))[1:12], 1), getindex((u(t))[1:12], 2), getindex((u(t))[1:12], 3), getindex((u(t))[1:12], 4), getindex((u(t))[1:12], 5), getindex((u(t))[1:12], 6), getindex((u(t))[1:12], 7), getindex((u(t))[1:12], 8), getindex((u(t))[1:12], 9), getindex((u(t))[1:12], 10), getindex((u(t))[1:12], 11), getindex((u(t))[1:12], 12)) */
controller_u_u28_t_u29 = vcat_f64_f64_f64_f64_f64_f64_f64_f64_f64_f64_f64_f64(getindex_f64x12_i64_28cdea89(u28_u_u28_t_u29_u29_u5b_1_colon_12_u5d, 1LL), getindex_f64x12_i64_f1365eec(u28_u_u28_t_u29_u29_u5b_1_colon_12_u5d, 2LL), getindex_f64x12_i64_9cb6e4c6(u28_u_u28_t_u29_u29_u5b_1_colon_12_u5d, 3LL), getindex_f64x12_i64_8a6206c2(u28_u_u28_t_u29_u29_u5b_1_colon_12_u5d, 4LL), getindex_f64x12_i64_70864f0d(u28_u_u28_t_u29_u29_u5b_1_colon_12_u5d, 5LL), getindex_f64x12_i64_36f60a18(u28_u_u28_t_u29_u29_u5b_1_colon_12_u5d, 6LL), getindex_f64x12_i64_798c8438(u28_u_u28_t_u29_u29_u5b_1_colon_12_u5d, 7LL), getindex_f64x12_i64_c29abda5(u28_u_u28_t_u29_u29_u5b_1_colon_12_u5d, 8LL), getindex_f64x12_i64_adc09d26(u28_u_u28_t_u29_u29_u5b_1_colon_12_u5d, 9LL), getindex_f64x12_i64_5879170b(u28_u_u28_t_u29_u29_u5b_1_colon_12_u5d, 10LL), getindex_f64x12_i64_e4285bab(u28_u_u28_t_u29_u29_u5b_1_colon_12_u5d, 11LL), getindex_f64x12_i64_081010bd(u28_u_u28_t_u29_u29_u5b_1_colon_12_u5d, 12LL));

/* equation anon@1 = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0] */
anon_1 = (SynchArray_f64x12){ 0 };

/* equation controller₊x(t)SYNshiftn1 = if first_tick@3 then anon@1 else controller₊x(t)@2 */
controller_x_u28_t_u29_SYNshiftn1 = ((first_tick_3) ? (anon_1) : (controller_x_u28_t_u29_2));

/* equation controller₊x(t) = +(*(getfield(when(pars, clock1), :controller₊A), controller₊x(t)SYNshiftn1), *(getfield(when(pars, clock1), :controller₊B), broadcast(-, controller₊u(t), getfield(when(pars, clock1), :controller₊u0)))) */
controller_x_u28_t_u29 = plus_f64x12_f64x12(mul_f64x12x12_f64x12(pars->controller_A, controller_x_u28_t_u29_SYNshiftn1), mul_f64x12x12_f64x12(pars->controller_B, broadcast_minus_f64x12_f64x12_56715569(controller_u_u28_t_u29, pars->controller_u0)));

/* equation controller₊y(t) = +(*(getfield(when(pars, clock1), :controller₊C), controller₊x(t)SYNshiftn1), *(getfield(when(pars, clock1), :controller₊D), broadcast(-, controller₊u(t), getfield(when(pars, clock1), :controller₊u0))), getfield(when(pars, clock1), :controller₊y0)) */
controller_y_u28_t_u29 = plus_f64x5_f64x5_f64x5(mul_f64x5x12_f64x12(pars->controller_C, controller_x_u28_t_u29_SYNshiftn1), mul_f64x5x12_f64x12(pars->controller_D, broadcast_minus_f64x12_f64x12_56715569(controller_u_u28_t_u29, pars->controller_u0)), pars->controller_y0);

/* equation (y(t))[1:5] = vcat(getindex(controller₊y(t), 1), getindex(controller₊y(t), 2), getindex(controller₊y(t), 3), getindex(controller₊y(t), 4), getindex(controller₊y(t), 5)) */
u28_y_u28_t_u29_u29_u5b_1_colon_5_u5d = vcat_f64_f64_f64_f64_f64(getindex_f64x5_i64_28cdea89(controller_y_u28_t_u29, 1LL), getindex_f64x5_i64_f1365eec(controller_y_u28_t_u29, 2LL), getindex_f64x5_i64_9cb6e4c6(controller_y_u28_t_u29, 3LL), getindex_f64x5_i64_8a6206c2(controller_y_u28_t_u29, 4LL), getindex_f64x5_i64_70864f0d(controller_y_u28_t_u29, 5LL));

/* equation controller₊x(t)@2 = pre(controller₊x(t)) */
self->controller_x_u28_t_u29 = controller_x_u28_t_u29;

/* equation first_tick@3 = pre(false; init=true) */
self->first_tick_3 = false;
}
top_f64x12_bool_Pars_out result;
result.u28_y_u28_t_u29_u29_u5b_1_colon_5_u5d = u28_y_u28_t_u29_u29_u5b_1_colon_5_u5d;
result.has_u28_y_u28_t_u29_u29_u5b_1_colon_5_u5d = clock1;
return result;
}
// cppcheck-suppress-end misra-c2012-8.7
/* C interface for @node top((u(t))[1:12]::SynchJulia.SynchVector{Float64, 12}, clock1::Bool, pars::SynchToolkit.var"##SynchRuntime#751".Pars) */
// cppcheck-suppress-begin misra-c2012-8.7 ; exported entry point
void top_f64x12_bool_Pars_step_c(const double u28_u_u28_t_u29_u29_u5b_1_colon_12_u5d[12], bool clock1, Pars * pars, double u28_y_u28_t_u29_u29_u5b_1_colon_5_u5d[5], bool * has_u28_y_u28_t_u29_u29_u5b_1_colon_5_u5d, top_f64x12_bool_Pars_mem * self) {
size_t i;
SynchArray_f64x12 u28_u_u28_t_u29_u29_u5b_1_colon_12_u5d_val;
top_f64x12_bool_Pars_out result;
for (i = 0U; i < 12U; i += 1U) {
u28_u_u28_t_u29_u29_u5b_1_colon_12_u5d_val.data.elements[i] = u28_u_u28_t_u29_u29_u5b_1_colon_12_u5d[i];
}
result = top_f64x12_bool_Pars_step(u28_u_u28_t_u29_u29_u5b_1_colon_12_u5d_val, clock1, pars, self);
*has_u28_y_u28_t_u29_u29_u5b_1_colon_5_u5d = result.has_u28_y_u28_t_u29_u29_u5b_1_colon_5_u5d;
if (*has_u28_y_u28_t_u29_u29_u5b_1_colon_5_u5d) {
for (i = 0U; i < 5U; i += 1U) {
u28_y_u28_t_u29_u29_u5b_1_colon_5_u5d[i] = result.u28_y_u28_t_u29_u29_u5b_1_colon_5_u5d.data.elements[i];
}
}
}
// cppcheck-suppress-end misra-c2012-8.7

/* reset for @node top at /Users/shobhitvoleti/.julia/packages/SynchToolkit/FUnNU/src/runtime_compiled.jl:76 */
// cppcheck-suppress-begin misra-c2012-8.7 ; exported entry point
void top_f64x12_bool_Pars_reset(top_f64x12_bool_Pars_mem* self) {
/* equation first_tick@3 = pre(false; init=true) */
self->first_tick_3 = true;
}
// cppcheck-suppress-end misra-c2012-8.7

const size_t top_f64x12_bool_Pars_state_size = sizeof(top_f64x12_bool_Pars_mem);
