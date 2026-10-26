#
#  Copyright (c) 2011-2013, ARM Limited. All rights reserved.
#
#  This program and the accompanying materials
#  are licensed and made available under the terms and conditions of the BSD License
#  which accompanies this distribution.  The full text of the license may be found at
#  http://opensource.org/licenses/bsd-license.php
#
#  THE PROGRAM IS DISTRIBUTED UNDER THE BSD LICENSE ON AN "AS IS" BASIS,
#  WITHOUT WARRANTIES OR REPRESENTATIONS OF ANY KIND, EITHER EXPRESS OR IMPLIED.
#
#

#include <AsmMacroIoLibV8.h>
#include <Base.h>
#include <Library/ArmLib.h>
#include <Library/PcdLib.h>
#include <AutoGen.h>

.text
.align 2

GCC_ASM_EXPORT(ArmPlatformPeiBootAction)
GCC_ASM_EXPORT(ArmPlatformIsPrimaryCore)
GCC_ASM_EXPORT(ArmPlatformGetPrimaryCoreMpId)
GCC_ASM_EXPORT(ArmPlatformGetCorePosition)
GCC_ASM_EXPORT(ArmGetPhysAddrTop)
GCC_ASM_EXPORT(ArmPlatformIsGicV2OrLower)
GCC_ASM_EXPORT(ArmPlatformSecondaryParking)

GCC_ASM_IMPORT(_gPcd_FixedAtBuild_PcdArmPrimaryCore)
GCC_ASM_IMPORT(_gPcd_FixedAtBuild_PcdArmPrimaryCoreMask)
GCC_ASM_IMPORT(_gPcd_FixedAtBuild_PcdCoreCount)

ASM_PFX(ArmPlatformPeiBootAction):
  mov    x19, x30
  bl     ASM_PFX(ArmPlatformIsPrimaryCore)
  cmp    x0, #1
  b.eq   .Lprimary
  bl     ASM_PFX(ArmPlatformIsGicV2OrLower)
  cmp    x0, #1
  b.eq   ASM_PFX(ArmPlatformSecondaryParking)

.Lprimary:
  mov    x30, x19
  ret

//UINTN
//ArmPlatformGetPrimaryCoreMpId (
//  VOID
//  );
ASM_PFX(ArmPlatformGetPrimaryCoreMpId):
  LoadConstantToReg (_gPcd_FixedAtBuild_PcdArmPrimaryCore, x0)
  ldrh   w0, [x0]
  ret

//UINTN
//ArmPlatformIsPrimaryCore (
//  IN UINTN MpId
//  );
ASM_PFX(ArmPlatformIsPrimaryCore):
  mrs   x0, mpidr_el1
  and   x0, x0, #0xff
  cmp   x0, #0
  cset  x0, eq
  ret

//UINTN
//ArmPlatformIsGicV2OrLower (
//  VOID
//  );
ASM_PFX(ArmPlatformIsGicV2OrLower):
  LoadConstantToReg (FixedPcdGet32 (PcdCpuGicDistributorBase), x1)
  ldr   w0, [x1, #4]
  and   w0, w0, #0x1f
  cmp   w0, #0x1f
  cset  w0, ne
  ret

//
// Park a secondary CPU in a WFI loop until the primary CPU writes a
// release address into this CPU's mailbox.
//
ASM_PFX(ArmPlatformSecondaryParking):
  mrs   x0, CurrentEL
  cmp   x0, #0x8
  b.ne  .Lparking_el1
  mrs   x0, hcr_el2
  mov   x1, #1
  lsl   x1, x1, #34           // HCR_EL2.E2H
  orr   x0, x0, x1
  msr   hcr_el2, x0
  isb
.Lparking_el1:
  msr   daifset, #0xf
  mrs   x0, CurrentEL
  cmp   x0, #0x8
  b.ne  .Ldisable_el1
  mrs   x1, sctlr_el2
  bic   x1, x1, #(1 << 12)    // I
  bic   x1, x1, #(1 << 2)     // C
  bic   x1, x1, #1            // M
  msr   sctlr_el2, x1
  isb
  b     .Lsctlr_done
.Ldisable_el1:
  mrs   x1, sctlr_el1
  bic   x1, x1, #(1 << 12)
  bic   x1, x1, #(1 << 2)
  bic   x1, x1, #1
  msr   sctlr_el1, x1
  isb
.Lsctlr_done:
  LoadConstantToReg (FixedPcdGet32 (PcdCpuGicInterruptInterfaceBase), x1)
  mov   w0, #1
  str   w0, [x1, #0]
  mov   w0, #0xff
  str   w0, [x1, #4]
  dsb   sy
  isb
  mrs   x0, mpidr_el1
  and   x0, x0, #0xff
  mov   x4, x0
  LoadConstantToReg (FixedPcdGet32 (PcdCpuMailboxBase), x5)
  add   x5, x5, x0, lsl #12
  str   x4, [x5, #0]
  mov   x0, #0
  str   x0, [x5, #8]
  dsb   sy
  isb
.Lparking_wait:
  wfi
  ldr   x3, [x5, #0]
  cmp   x3, x4
  b.ne  .Lparking_wait
  ldr   x3, [x5, #8]
  cbz   x3, .Lparking_wait
  mov   x0, #0
  str   x0, [x5, #8]
  dsb   sy
  isb
  mov   x0, x5
  br    x3

//UINTN
//ArmPlatformGetCorePosition (
//  IN UINTN MpId
//  );
// With this function: CorePos = (ClusterId * 4) + CoreId
ASM_PFX(ArmPlatformGetCorePosition):
  and   x1, x0, #ARM_CORE_MASK
  and   x0, x0, #ARM_CLUSTER_MASK
  add   x0, x1, x0, LSR #6
  ret

//EFI_PHYSICAL_ADDRESS
//GetPhysAddrTop (
//  VOID
//  );
ASM_PFX(ArmGetPhysAddrTop):
  mrs   x0, id_aa64mmfr0_el1
  adr   x1, .LPARanges
  and   x0, x0, #7
  ldrb  w1, [x1, x0]
  mov   x0, #1
  lsl   x0, x0, x1
  ret

//
// Bits 0..2 of the AA64MFR0_EL1 system register encode the size of the
// physical address space support on this CPU:
// 0 == 32 bits, 1 == 36 bits, etc etc
// 6 and 7 are reserved
//
.LPARanges:
  .byte 32, 36, 40, 42, 44, 48, -1, -1

ASM_FUNCTION_REMOVE_IF_UNREFERENCED
