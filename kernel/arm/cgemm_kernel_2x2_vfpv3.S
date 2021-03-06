/***************************************************************************
Copyright (c) 2013, The OpenBLAS Project
All rights reserved.
Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are
met:
1. Redistributions of source code must retain the above copyright
notice, this list of conditions and the following disclaimer.
2. Redistributions in binary form must reproduce the above copyright
notice, this list of conditions and the following disclaimer in
the documentation and/or other materials provided with the
distribution.
3. Neither the name of the OpenBLAS project nor the names of
its contributors may be used to endorse or promote products
derived from this software without specific prior written permission.
THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
ARE DISCLAIMED. IN NO EVENT SHALL THE OPENBLAS PROJECT OR CONTRIBUTORS BE
LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE
USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*****************************************************************************/

/**************************************************************************************
* 2013/11/05 Saar
* 	 BLASTEST 		: OK
* 	 CTEST			: OK
* 	 TEST			: OK
*
* 2013/11/01 Saar
*       UNROLL_N                2
*       UNROLL_M                2
*       CGEMM_P                 96
*       CGEMM_Q                 120
*       CGEMM_R                 4096
*       A_PRE                   96
*       B_PRE                   96
*       C_PRE                   64
*
*       Performance on Odroid U2:
*
*               1 Core:         2.59 GFLOPS     ATLAS: 2.37     GFLOPS
*               2 Cores:        5.17 GFLOPS     ATLAS: 4.46     GFLOPS
*               3 Cores:        7.69 GFLOPS     ATLAS: 6.50     GFLOPS
*               4 Cores:       10.22 GFLOPS     ATLAS: 8.18     GFLOPS
**************************************************************************************/

#define ASSEMBLER
#include "common.h"

#define STACKSIZE 256

#define	OLD_M	r0
#define	OLD_N	r1
#define	OLD_K	r2
#define	OLD_A	r3
#define OLD_ALPHA_R s0
#define OLD_ALPHA_I s1

/******************************************************
* [fp, #-128] - [fp, #-64] is reserved
* for store and restore of floating point
* registers
*******************************************************/

#define A	[fp, #-248 ]
#define LDC	[fp, #-252 ]
#define M	[fp, #-256 ]
#define N	[fp, #-260 ]
#define K	[fp, #-264 ]

#define ALPHA_I	[fp, #-272]
#define ALPHA_R	[fp, #-280]

#define B	[fp, #4 ]
#define C	[fp, #8 ]
#define OLD_LDC	[fp, #12 ]

#define I	r0
#define J	r1
#define L	r2

#define	AO	r5
#define	BO	r6

#define	CO1	r8
#define	CO2	r9

#define K1	r7
#define BC	r12

#define A_PRE	96
#define B_PRE	96
#define C_PRE	64

#if defined(NN) || defined(NT) || defined(TN) || defined(TT)

	#define	FADD_R	fsubs
	#define	FADD_I	fadds

	#define	FMAC_R1	fnmacs
	#define	FMAC_R2	fnmacs
	#define	FMAC_I1	fmacs
	#define	FMAC_I2	fnmacs

#elif defined(CN) || defined(CT)

	#define	FADD_R	fadds
	#define	FADD_I	fsubs

	#define	FMAC_R1	fmacs
	#define	FMAC_R2	fmacs
	#define	FMAC_I1	fnmacs
	#define	FMAC_I2	fmacs

#elif defined(NC) || defined(TC)

	#define	FADD_R	fadds
	#define	FADD_I	fsubs

	#define	FMAC_R1	fmacs
	#define	FMAC_R2	fnmacs
	#define	FMAC_I1	fmacs
	#define	FMAC_I2	fmacs

#else

	#define	FADD_R  fsubs
	#define	FADD_I	fadds

	#define	FMAC_R1	fnmacs
	#define	FMAC_R2	fmacs
	#define	FMAC_I1	fnmacs
	#define	FMAC_I2	fnmacs

#endif



/**************************************************************************************
* Macro definitions
**************************************************************************************/

.macro INIT2x2

	vmov.f32		s17, s16
	vmov.f32		s18, s16
	vmov.f32		s19, s16
	vmov.f32		s20, s16
	vmov.f32		s21, s16
	vmov.f32		s22, s16
	vmov.f32		s23, s16
	vmov.f32		s24, s16
	vmov.f32		s25, s16
	vmov.f32		s26, s16
	vmov.f32		s27, s16
	vmov.f32		s28, s16
	vmov.f32		s29, s16
	vmov.f32		s30, s16
	vmov.f32		s31, s16

.endm

.macro KERNEL2x2_I
	pld	[ AO , #A_PRE ]
	pld	[ BO , #B_PRE ]
	fldmias AO!, { s0 - s1 }
	fldmias BO!, { s8 - s9 }

	fmuls	s16  , s0,  s8
	fmuls	s24  , s1,  s9
	fldmias AO!, { s2 - s3 }
	fmuls	s17  , s0,  s9
	fmuls	s25  , s1,  s8

	fldmias BO!, { s10 - s11 }
	fmuls	s18  , s2,  s8
	fmuls	s26  , s3,  s9
	fldmias AO!, { s4 - s5 }
	fmuls	s19  , s2,  s9
	fmuls	s27  , s3,  s8

	fldmias BO!, { s12 - s13 }
	fmuls	s20  , s0,  s10
	fmuls	s28  , s1,  s11
	fldmias AO!, { s6 - s7 }
	fmuls	s21  , s0,  s11
	fmuls	s29  , s1,  s10

	fldmias BO!, { s14 - s15 }
	fmuls	s22  , s2,  s10
	fmuls	s30  , s3,  s11
	fmuls	s23  , s2,  s11
	fmuls	s31  , s3,  s10

.endm



.macro KERNEL2x2_M1

	fmacs	s16  , s0,  s8
	fldmias AO!, { s4 - s5 }
	fmacs	s24  , s1,  s9
	fmacs	s17  , s0,  s9
	fldmias BO!, { s12 - s13 }
	fmacs	s25  , s1,  s8

	fmacs	s18  , s2,  s8
	fldmias AO!, { s6 - s7 }
	fmacs	s26  , s3,  s9
	fmacs	s19  , s2,  s9
	fldmias BO!, { s14 - s15 }
	fmacs	s27  , s3,  s8

	fmacs	s20  , s0,  s10
	fmacs	s28  , s1,  s11
	fmacs	s21  , s0,  s11
	fmacs	s29  , s1,  s10

	fmacs	s22  , s2,  s10
	fmacs	s30  , s3,  s11
	fmacs	s23  , s2,  s11
	fmacs	s31  , s3,  s10

.endm

.macro KERNEL2x2_M2
	pld	[ AO , #A_PRE ]

	fmacs	s16  , s4,  s12
	pld	[ BO , #B_PRE ]
	fmacs	s24  , s5,  s13
	fmacs	s17  , s4,  s13
	fldmias AO!, { s0 - s1 }
	fmacs	s25  , s5,  s12

	fmacs	s18  , s6,  s12
	fmacs	s26  , s7,  s13
	fldmias BO!, { s8 - s9 }
	fmacs	s19  , s6,  s13
	fmacs	s27  , s7,  s12

	fldmias AO!, { s2 - s3 }
	fmacs	s20  , s4,  s14
	fmacs	s28  , s5,  s15
	fldmias BO!, { s10 - s11 }
	fmacs	s21  , s4,  s15
	fmacs	s29  , s5,  s14

	fmacs	s22  , s6,  s14
	fmacs	s30  , s7,  s15
	fmacs	s23  , s6,  s15
	fmacs	s31  , s7,  s14

.endm


.macro KERNEL2x2_E

	fmacs	s16  , s4,  s12
	fmacs	s24  , s5,  s13
	fmacs	s17  , s4,  s13
	fmacs	s25  , s5,  s12

	fmacs	s18  , s6,  s12
	fmacs	s26  , s7,  s13
	fmacs	s19  , s6,  s13
	fmacs	s27  , s7,  s12

	fmacs	s20  , s4,  s14
	fmacs	s28  , s5,  s15
	fmacs	s21  , s4,  s15
	fmacs	s29  , s5,  s14

	fmacs	s22  , s6,  s14
	fmacs	s30  , s7,  s15
	fmacs	s23  , s6,  s15
	fmacs	s31  , s7,  s14

.endm

.macro KERNEL2x2_SUB

	fldmias AO!, { s0 - s1 }
	fldmias BO!, { s8 - s9 }

	fmacs	s16  , s0,  s8
	fmacs	s24  , s1,  s9
	fldmias AO!, { s2 - s3 }
	fmacs	s17  , s0,  s9
	fmacs	s25  , s1,  s8

	fldmias BO!, { s10 - s11 }
	fmacs	s18  , s2,  s8
	fmacs	s26  , s3,  s9
	fmacs	s19  , s2,  s9
	fmacs	s27  , s3,  s8

	fmacs	s20  , s0,  s10
	fmacs	s28  , s1,  s11
	fmacs	s21  , s0,  s11
	fmacs	s29  , s1,  s10

	fmacs	s22  , s2,  s10
	fmacs	s30  , s3,  s11
	fmacs	s23  , s2,  s11
	fmacs	s31  , s3,  s10

.endm




.macro SAVE2x2
	pld	[ CO1 , #C_PRE ]

	ldr	r3  , LDC
	add	CO2 , CO1, r3
	flds		s0, ALPHA_R
	flds		s1, ALPHA_I

	fldmias CO1, { s4 - s7 }
	fldmias CO2, { s8 - s11 }

	FADD_R	s16, s24 , s16
	FADD_I  s17, s25 , s17
	FADD_R	s18, s26 , s18
	FADD_I  s19, s27 , s19
	FADD_R	s20, s28 , s20
	FADD_I  s21, s29 , s21
	FADD_R	s22, s30 , s22
	FADD_I  s23, s31 , s23

	FMAC_R1 s4 , s0 , s16
	FMAC_I1 s5 , s0 , s17
	FMAC_R2 s4 , s1 , s17
	FMAC_I2	s5 , s1 , s16

	FMAC_R1 s6 , s0 , s18
	FMAC_I1 s7 , s0 , s19
	FMAC_R2 s6 , s1 , s19
	FMAC_I2	s7 , s1 , s18

	FMAC_R1 s8 , s0 , s20
	FMAC_I1 s9 , s0 , s21
	FMAC_R2 s8 , s1 , s21
	FMAC_I2	s9 , s1 , s20

	FMAC_R1 s10, s0 , s22
	FMAC_I1 s11, s0 , s23
	FMAC_R2 s10, s1 , s23
	FMAC_I2	s11, s1 , s22

	fstmias CO1, { s4 - s7 }
	fstmias CO2, { s8 - s11 }

	add	CO1, CO1, #16

.endm

/******************************************************************************/

.macro INIT1x2

	vmov.f32		s17, s16
	vmov.f32		s20, s16
	vmov.f32		s21, s16
	vmov.f32		s24, s16
	vmov.f32		s25, s16
	vmov.f32		s28, s16
	vmov.f32		s29, s16

.endm

.macro KERNEL1x2_I
	pld	[ AO , #A_PRE ]
	pld	[ BO , #B_PRE ]
	flds	s0 , [ AO ]
	flds	s1 , [ AO, #4 ]
	flds	s8 , [ BO ]
	flds	s9 , [ BO, #4 ]
	flds	s10, [ BO, #8 ]
	flds	s11, [ BO, #12 ]

	fmuls	s16  , s0,  s8
	fmuls	s24  , s1,  s9
	fmuls	s17  , s0,  s9
	fmuls	s25  , s1,  s8

	fmuls	s20  , s0,  s10
	fmuls	s28  , s1,  s11
	fmuls	s21  , s0,  s11
	fmuls	s29  , s1,  s10

	add	BO , BO, #16
	add	AO , AO, #8

	pld	[ BO , #B_PRE ]

	flds	s4 , [ AO, #0 ]
	flds	s5 , [ AO, #4 ]

	flds	s12, [ BO ]
	flds	s13, [ BO, #4 ]
	flds	s14, [ BO, #8 ]
	flds	s15, [ BO, #12 ]

	add	BO , BO, #16
	add	AO , AO, #8
.endm



.macro KERNEL1x2_M1
	pld	[ BO , #B_PRE ]

	fmacs	s16  , s0,  s8
	fmacs	s24  , s1,  s9
	fmacs	s17  , s0,  s9
	fmacs	s25  , s1,  s8

	fmacs	s20  , s0,  s10
	fmacs	s28  , s1,  s11
	fmacs	s21  , s0,  s11
	fmacs	s29  , s1,  s10

	flds	s4 , [ AO, #0 ]
	flds	s5 , [ AO, #4 ]

	flds	s12, [ BO ]
	flds	s13, [ BO, #4 ]
	flds	s14, [ BO, #8 ]
	flds	s15, [ BO, #12 ]

	add	BO , BO, #16
	add	AO , AO, #8
.endm

.macro KERNEL1x2_M2
	pld	[ AO , #A_PRE ]
	pld	[ BO , #B_PRE ]

	fmacs	s16  , s4,  s12
	fmacs	s24  , s5,  s13
	fmacs	s17  , s4,  s13
	fmacs	s25  , s5,  s12

	fmacs	s20  , s4,  s14
	fmacs	s28  , s5,  s15
	fmacs	s21  , s4,  s15
	fmacs	s29  , s5,  s14

	flds	s0 , [ AO, #0 ]
	flds	s1 , [ AO, #4 ]

	flds	s8 , [ BO ]
	flds	s9 , [ BO, #4 ]
	flds	s10, [ BO, #8 ]
	flds	s11, [ BO, #12 ]

	add	BO , BO, #16
	add	AO , AO, #8
.endm


.macro KERNEL1x2_E

	fmacs	s16  , s4,  s12
	fmacs	s24  , s5,  s13
	fmacs	s17  , s4,  s13
	fmacs	s25  , s5,  s12

	fmacs	s20  , s4,  s14
	fmacs	s28  , s5,  s15
	fmacs	s21  , s4,  s15
	fmacs	s29  , s5,  s14

.endm

.macro KERNEL1x2_SUB

	pld	[ AO , #A_PRE ]
	pld	[ BO , #B_PRE ]
	flds	s0 , [ AO ]
	flds	s1 , [ AO, #4 ]
	flds	s8 , [ BO ]
	flds	s9 , [ BO, #4 ]
	flds	s10, [ BO, #8 ]
	flds	s11, [ BO, #12 ]

	fmacs	s16  , s0,  s8
	fmacs	s24  , s1,  s9
	fmacs	s17  , s0,  s9
	fmacs	s25  , s1,  s8

	fmacs	s20  , s0,  s10
	fmacs	s28  , s1,  s11
	fmacs	s21  , s0,  s11
	fmacs	s29  , s1,  s10

	add	BO , BO, #16
	add	AO , AO, #8

.endm




.macro SAVE1x2
	pld	[ CO1 , #C_PRE ]

	ldr	r3  , LDC
	add	CO2 , CO1, r3
	flds		s0, ALPHA_R
	flds		s1, ALPHA_I

	fldmias CO1, { s4 - s5 }
	fldmias CO2, { s8 - s9  }

	FADD_R	s16, s24 , s16
	FADD_I  s17, s25 , s17
	FADD_R	s20, s28 , s20
	FADD_I  s21, s29 , s21

	FMAC_R1 s4 , s0 , s16
	FMAC_I1 s5 , s0 , s17
	FMAC_R2 s4 , s1 , s17
	FMAC_I2	s5 , s1 , s16

	FMAC_R1 s8 , s0 , s20
	FMAC_I1 s9 , s0 , s21
	FMAC_R2 s8 , s1 , s21
	FMAC_I2	s9 , s1 , s20

	fstmias CO1, { s4 - s5 }
	fstmias CO2, { s8 - s9  }

	add	CO1, CO1, #8

.endm

/******************************************************************************/

.macro INIT2x1

	vmov.f32		s17, s16
	vmov.f32		s18, s16
	vmov.f32		s19, s16
	vmov.f32		s24, s16
	vmov.f32		s25, s16
	vmov.f32		s26, s16
	vmov.f32		s27, s16

.endm

.macro KERNEL2x1_I
	pld	[ AO , #A_PRE ]
	pld	[ BO , #B_PRE ]
	flds	s0 , [ AO ]
	flds	s1 , [ AO, #4 ]
	flds	s2 , [ AO, #8 ]
	flds	s3 , [ AO, #12 ]
	flds	s8 , [ BO ]
	flds	s9 , [ BO, #4 ]

	fmuls	s16  , s0,  s8
	fmuls	s24  , s1,  s9
	fmuls	s17  , s0,  s9
	fmuls	s25  , s1,  s8

	fmuls	s18  , s2,  s8
	fmuls	s26  , s3,  s9
	fmuls	s19  , s2,  s9
	fmuls	s27  , s3,  s8

	add	BO , BO, #8
	add	AO , AO, #16

	pld	[ BO , #B_PRE ]
	pld	[ AO , #A_PRE ]

	flds	s4 , [ AO, #0 ]
	flds	s5 , [ AO, #4 ]
	flds	s6 , [ AO, #8 ]
	flds	s7 , [ AO, #12 ]

	flds	s12, [ BO ]
	flds	s13, [ BO, #4 ]

	add	BO , BO, #8
	add	AO , AO, #16
.endm



.macro KERNEL2x1_M1
	pld	[ AO , #A_PRE ]
	pld	[ BO , #B_PRE ]

	fmacs	s16  , s0,  s8
	fmacs	s24  , s1,  s9
	fmacs	s17  , s0,  s9
	fmacs	s25  , s1,  s8

	fmacs	s18  , s2,  s8
	fmacs	s26  , s3,  s9
	fmacs	s19  , s2,  s9
	fmacs	s27  , s3,  s8

	flds	s4 , [ AO, #0 ]
	flds	s5 , [ AO, #4 ]
	flds	s6 , [ AO, #8 ]
	flds	s7 , [ AO, #12 ]

	flds	s12, [ BO ]
	flds	s13, [ BO, #4 ]

	add	BO , BO, #8
	add	AO , AO, #16
.endm

.macro KERNEL2x1_M2
	pld	[ AO , #A_PRE ]
	pld	[ BO , #B_PRE ]

	fmacs	s16  , s4,  s12
	fmacs	s24  , s5,  s13
	fmacs	s17  , s4,  s13
	fmacs	s25  , s5,  s12

	fmacs	s18  , s6,  s12
	fmacs	s26  , s7,  s13
	fmacs	s19  , s6,  s13
	fmacs	s27  , s7,  s12

	flds	s0 , [ AO, #0 ]
	flds	s1 , [ AO, #4 ]
	flds	s2 , [ AO, #8 ]
	flds	s3 , [ AO, #12 ]

	flds	s8 , [ BO ]
	flds	s9 , [ BO, #4 ]

	add	BO , BO, #8
	add	AO , AO, #16
.endm


.macro KERNEL2x1_E

	fmacs	s16  , s4,  s12
	fmacs	s24  , s5,  s13
	fmacs	s17  , s4,  s13
	fmacs	s25  , s5,  s12

	fmacs	s18  , s6,  s12
	fmacs	s26  , s7,  s13
	fmacs	s19  , s6,  s13
	fmacs	s27  , s7,  s12

.endm

.macro KERNEL2x1_SUB

	pld	[ AO , #A_PRE ]
	pld	[ BO , #B_PRE ]
	flds	s0 , [ AO ]
	flds	s1 , [ AO, #4 ]
	flds	s2 , [ AO, #8 ]
	flds	s3 , [ AO, #12 ]
	flds	s8 , [ BO ]
	flds	s9 , [ BO, #4 ]

	fmacs	s16  , s0,  s8
	fmacs	s24  , s1,  s9
	fmacs	s17  , s0,  s9
	fmacs	s25  , s1,  s8

	fmacs	s18  , s2,  s8
	fmacs	s26  , s3,  s9
	fmacs	s19  , s2,  s9
	fmacs	s27  , s3,  s8

	add	BO , BO, #8
	add	AO , AO, #16

.endm




.macro SAVE2x1
	pld	[ CO1 , #C_PRE ]

	flds		s0, ALPHA_R
	flds		s1, ALPHA_I

	fldmias CO1, { s4 - s7 }

	FADD_R	s16, s24 , s16
	FADD_I  s17, s25 , s17
	FADD_R	s18, s26 , s18
	FADD_I  s19, s27 , s19

	FMAC_R1 s4 , s0 , s16
	FMAC_I1 s5 , s0 , s17
	FMAC_R2 s4 , s1 , s17
	FMAC_I2	s5 , s1 , s16

	FMAC_R1 s6 , s0 , s18
	FMAC_I1 s7 , s0 , s19
	FMAC_R2 s6 , s1 , s19
	FMAC_I2	s7 , s1 , s18

	fstmias CO1, { s4 - s7 }

	add	CO1, CO1, #16

.endm

/******************************************************************************/

.macro INIT1x1

	vmov.f32		s17, s16
	vmov.f32		s24, s16
	vmov.f32		s25, s16

.endm

.macro KERNEL1x1_I
	pld	[ AO , #A_PRE ]
	pld	[ BO , #B_PRE ]
	flds	s0 , [ AO ]
	flds	s1 , [ AO, #4 ]
	flds	s8 , [ BO ]
	flds	s9 , [ BO, #4 ]

	fmuls	s16  , s0,  s8
	fmuls	s24  , s1,  s9
	fmuls	s17  , s0,  s9
	fmuls	s25  , s1,  s8

	add	BO , BO, #8
	add	AO , AO, #8

	pld	[ BO , #B_PRE ]
	pld	[ AO , #A_PRE ]

	flds	s4 , [ AO, #0 ]
	flds	s5 , [ AO, #4 ]

	flds	s12, [ BO ]
	flds	s13, [ BO, #4 ]

	add	BO , BO, #8
	add	AO , AO, #8
.endm



.macro KERNEL1x1_M1

	fmacs	s16  , s0,  s8
	fmacs	s24  , s1,  s9
	fmacs	s17  , s0,  s9
	fmacs	s25  , s1,  s8

	flds	s4 , [ AO, #0 ]
	flds	s5 , [ AO, #4 ]

	flds	s12, [ BO ]
	flds	s13, [ BO, #4 ]

	add	BO , BO, #8
	add	AO , AO, #8
.endm

.macro KERNEL1x1_M2

	fmacs	s16  , s4,  s12
	fmacs	s24  , s5,  s13
	fmacs	s17  , s4,  s13
	fmacs	s25  , s5,  s12

	flds	s0 , [ AO, #0 ]
	flds	s1 , [ AO, #4 ]

	flds	s8 , [ BO ]
	flds	s9 , [ BO, #4 ]

	add	BO , BO, #8
	add	AO , AO, #8
.endm


.macro KERNEL1x1_E

	fmacs	s16  , s4,  s12
	fmacs	s24  , s5,  s13
	fmacs	s17  , s4,  s13
	fmacs	s25  , s5,  s12

.endm

.macro KERNEL1x1_SUB

	flds	s0 , [ AO ]
	flds	s1 , [ AO, #4 ]
	flds	s8 , [ BO ]
	flds	s9 , [ BO, #4 ]

	fmacs	s16  , s0,  s8
	fmacs	s24  , s1,  s9
	fmacs	s17  , s0,  s9
	fmacs	s25  , s1,  s8

	add	BO , BO, #8
	add	AO , AO, #8

.endm




.macro SAVE1x1
	pld	[ CO1 , #C_PRE ]

	flds		s0, ALPHA_R
	flds		s1, ALPHA_I

	fldmias CO1, { s4 - s5 }

	FADD_R	s16, s24 , s16
	FADD_I  s17, s25 , s17

	FMAC_R1 s4 , s0 , s16
	FMAC_I1 s5 , s0 , s17
	FMAC_R2 s4 , s1 , s17
	FMAC_I2	s5 , s1 , s16

	fstmias CO1, { s4 - s5 }

	add	CO1, CO1, #8

.endm

/******************************************************************************/


/**************************************************************************************
* End of macro definitions
**************************************************************************************/

	PROLOGUE

	.align 5

	push	{r4 - r9, fp}
	add	fp, sp, #24
	sub	sp, sp, #STACKSIZE				// reserve stack

	str	OLD_M, M
	str	OLD_N, N
	str	OLD_K, K
	str	OLD_A, A
	vstr	OLD_ALPHA_R, ALPHA_R
	vstr	OLD_ALPHA_I, ALPHA_I

	sub	r3, fp, #128
	vstm	r3, { s8 - s31} 				// store floating point registers

	ldr	r3, OLD_LDC
	lsl	r3, r3, #3					// ldc = ldc * 4 * 2
	str	r3, LDC

	ldr	K1, K
	ldr	BC, B

	ldr	J, N
	asrs	J, J, #1					// J = J / 2
	ble	cgemm_kernel_L1_BEGIN

cgemm_kernel_L2_BEGIN:

	ldr	CO1, C						// CO1 = C
	ldr	r4 , LDC
	lsl	r4 , r4 , #1					// LDC * 2
	add	r3 , r4, CO1
	str	r3 , C						// store C

	ldr	AO, A						// AO = A
        pld     [AO , #A_PRE-64]
        pld     [AO , #A_PRE-32]



cgemm_kernel_L2_M2_BEGIN:

	ldr	I, M
	asrs	I, I, #1					// I = I / 2
	ble	cgemm_kernel_L2_M1_BEGIN

cgemm_kernel_L2_M2_20:


	mov	BO, BC
	asrs	L , K1, #3					// L = L / 8
	cmp	L , #3
	blt	cgemm_kernel_L2_M2_30
	.align 5



	KERNEL2x2_I
	KERNEL2x2_M2
	KERNEL2x2_M1
	KERNEL2x2_M2

	KERNEL2x2_M1
	KERNEL2x2_M2
	KERNEL2x2_M1
	KERNEL2x2_M2

	sub	L, L, #2

cgemm_kernel_L2_M2_22:

	KERNEL2x2_M1
	KERNEL2x2_M2
	KERNEL2x2_M1
	KERNEL2x2_M2

	KERNEL2x2_M1
	KERNEL2x2_M2
	KERNEL2x2_M1
	KERNEL2x2_M2

	subs	L, L, #1
	bgt	cgemm_kernel_L2_M2_22

	KERNEL2x2_M1
	KERNEL2x2_M2
	KERNEL2x2_M1
	KERNEL2x2_M2

	KERNEL2x2_M1
	KERNEL2x2_M2
	KERNEL2x2_M1
	KERNEL2x2_E

	b	 cgemm_kernel_L2_M2_44


cgemm_kernel_L2_M2_30:
	tst	L, #3
	ble	cgemm_kernel_L2_M2_40

	tst	L, #2
	ble	cgemm_kernel_L2_M2_32

	KERNEL2x2_I
	KERNEL2x2_M2
	KERNEL2x2_M1
	KERNEL2x2_M2

	KERNEL2x2_M1
	KERNEL2x2_M2
	KERNEL2x2_M1
	KERNEL2x2_M2

	KERNEL2x2_M1
	KERNEL2x2_M2
	KERNEL2x2_M1
	KERNEL2x2_M2


	KERNEL2x2_M1
	KERNEL2x2_M2
	KERNEL2x2_M1
	KERNEL2x2_E

	b	 cgemm_kernel_L2_M2_44

cgemm_kernel_L2_M2_32:

	tst	L, #1
	ble	cgemm_kernel_L2_M2_40

	KERNEL2x2_I
	KERNEL2x2_M2
	KERNEL2x2_M1
	KERNEL2x2_M2

	KERNEL2x2_M1
	KERNEL2x2_M2
	KERNEL2x2_M1
	KERNEL2x2_E

	b	 cgemm_kernel_L2_M2_44

cgemm_f32zero:
        .word 0x00000000

cgemm_kernel_L2_M2_40:

	vldr.f32		s16 , cgemm_f32zero
	INIT2x2


cgemm_kernel_L2_M2_44:

	ands	L , K1, #7					// L = L % 8
	ble	cgemm_kernel_L2_M2_100

cgemm_kernel_L2_M2_46:

	KERNEL2x2_SUB

	subs	L, L, #1
	bne	cgemm_kernel_L2_M2_46

cgemm_kernel_L2_M2_100:

	SAVE2x2

cgemm_kernel_L2_M2_END:

	subs	I, I, #1
	bne	cgemm_kernel_L2_M2_20


cgemm_kernel_L2_M1_BEGIN:

	ldr	I, M
	tst	I, #1					// I = I % 2
	ble	cgemm_kernel_L2_END

cgemm_kernel_L2_M1_20:

	vldr.f32		s16 , cgemm_f32zero
	INIT1x2

	mov	BO, BC
	asrs	L , K1, #3					// L = L / 8
	ble	cgemm_kernel_L2_M1_40

cgemm_kernel_L2_M1_22:

	KERNEL1x2_SUB
	KERNEL1x2_SUB
	KERNEL1x2_SUB
	KERNEL1x2_SUB

	KERNEL1x2_SUB
	KERNEL1x2_SUB
	KERNEL1x2_SUB
	KERNEL1x2_SUB

	subs	L, L, #1
	bgt	cgemm_kernel_L2_M1_22


cgemm_kernel_L2_M1_40:

	ands	L , K1, #7					// L = L % 8
	ble	cgemm_kernel_L2_M1_100

cgemm_kernel_L2_M1_42:

	KERNEL1x2_SUB

	subs	L, L, #1
	bgt	cgemm_kernel_L2_M1_42

cgemm_kernel_L2_M1_100:

	SAVE1x2


cgemm_kernel_L2_END:

	mov	r3, BC
	mov	r4, K1
	lsl	r4, r4, #4					// k * 2 * 4 * 2
	add	r3, r3, r4					// B = B + K * 2 * 8
	mov	BC, r3

	subs	J , #1						// j--
	bgt	cgemm_kernel_L2_BEGIN



/*********************************************************************************************/

cgemm_kernel_L1_BEGIN:

	ldr	J , N
	tst	J , #1
	ble	cgemm_kernel_L999


	ldr	CO1, C						// CO1 = C
	ldr	r4 , LDC
	add	r3 , r4, CO1
	str	r3 , C						// store C

	ldr	AO, A						// AO = A

cgemm_kernel_L1_M2_BEGIN:

	ldr	I, M
	asrs	I, I, #1					// I = I / 2
	ble	cgemm_kernel_L1_M1_BEGIN

cgemm_kernel_L1_M2_20:


	mov	BO, BC
	asrs	L , K1, #3					// L = L / 8
	cmp	L , #3
	blt	cgemm_kernel_L1_M2_30
	.align 5



	KERNEL2x1_I
	KERNEL2x1_M2
	KERNEL2x1_M1
	KERNEL2x1_M2

	KERNEL2x1_M1
	KERNEL2x1_M2
	KERNEL2x1_M1
	KERNEL2x1_M2

	sub	L, L, #2

cgemm_kernel_L1_M2_22:

	KERNEL2x1_M1
	KERNEL2x1_M2
	KERNEL2x1_M1
	KERNEL2x1_M2

	KERNEL2x1_M1
	KERNEL2x1_M2
	KERNEL2x1_M1
	KERNEL2x1_M2

	subs	L, L, #1
	bgt	cgemm_kernel_L1_M2_22

	KERNEL2x1_M1
	KERNEL2x1_M2
	KERNEL2x1_M1
	KERNEL2x1_M2

	KERNEL2x1_M1
	KERNEL2x1_M2
	KERNEL2x1_M1
	KERNEL2x1_E

	b	 cgemm_kernel_L1_M2_44


cgemm_kernel_L1_M2_30:
	tst	L, #3
	ble	cgemm_kernel_L1_M2_40

	tst	L, #2
	ble	cgemm_kernel_L1_M2_32

	KERNEL2x1_I
	KERNEL2x1_M2
	KERNEL2x1_M1
	KERNEL2x1_M2

	KERNEL2x1_M1
	KERNEL2x1_M2
	KERNEL2x1_M1
	KERNEL2x1_M2

	KERNEL2x1_M1
	KERNEL2x1_M2
	KERNEL2x1_M1
	KERNEL2x1_M2


	KERNEL2x1_M1
	KERNEL2x1_M2
	KERNEL2x1_M1
	KERNEL2x1_E

	b	 cgemm_kernel_L1_M2_44

cgemm_kernel_L1_M2_32:

	tst	L, #1
	ble	cgemm_kernel_L1_M2_40

	KERNEL2x1_I
	KERNEL2x1_M2
	KERNEL2x1_M1
	KERNEL2x1_M2

	KERNEL2x1_M1
	KERNEL2x1_M2
	KERNEL2x1_M1
	KERNEL2x1_E

	b	 cgemm_kernel_L1_M2_44


cgemm_kernel_L1_M2_40:

	vldr.f32		s16 , =0
	INIT2x1


cgemm_kernel_L1_M2_44:

	ands	L , K1, #7					// L = L % 8
	ble	cgemm_kernel_L1_M2_100

cgemm_kernel_L1_M2_46:

	KERNEL2x1_SUB

	subs	L, L, #1
	bne	cgemm_kernel_L1_M2_46

cgemm_kernel_L1_M2_100:

	SAVE2x1

cgemm_kernel_L1_M2_END:

	subs	I, I, #1
	bne	cgemm_kernel_L1_M2_20


cgemm_kernel_L1_M1_BEGIN:

	ldr	I, M
	tst	I, #1					// I = I % 2
	ble	cgemm_kernel_L1_END

cgemm_kernel_L1_M1_20:

	vldr.f32		s16 , =0
	INIT1x1

	mov	BO, BC
	asrs	L , K1, #3					// L = L / 8
	ble	cgemm_kernel_L1_M1_40

cgemm_kernel_L1_M1_22:

	KERNEL1x1_SUB
	KERNEL1x1_SUB
	KERNEL1x1_SUB
	KERNEL1x1_SUB

	KERNEL1x1_SUB
	KERNEL1x1_SUB
	KERNEL1x1_SUB
	KERNEL1x1_SUB

	subs	L, L, #1
	bgt	cgemm_kernel_L1_M1_22


cgemm_kernel_L1_M1_40:

	ands	L , K1, #7					// L = L % 8
	ble	cgemm_kernel_L1_M1_100

cgemm_kernel_L1_M1_42:

	KERNEL1x1_SUB

	subs	L, L, #1
	bgt	cgemm_kernel_L1_M1_42

cgemm_kernel_L1_M1_100:

	SAVE1x1


cgemm_kernel_L1_END:



cgemm_kernel_L999:

	sub	r3, fp, #128
	vldm	r3, { s8 - s31}					// restore floating point registers

	movs	r0, #0						// set return value
	sub	sp, fp, #24
	pop	{r4 - r9, fp}
	bx	lr

	EPILOGUE

