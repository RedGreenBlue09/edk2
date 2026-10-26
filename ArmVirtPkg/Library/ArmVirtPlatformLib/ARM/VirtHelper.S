#
#  Copyright (c) 2011-2013, ARM Limited. All rights reserved.
#  Copyright (c) 2014, Linaro Limited. All rights reserved.
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

#include <AsmMacroIoLib.h>
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
  mov   r12, lr
  bl    ASM_PFX(ArmPlatformIsPrimaryCore)
  cmp   r0, #1
  beq   _PrimaryCore
  bl    ASM_PFX(ArmPlatformIsGicV2OrLower)
  cmp   r0, #1
  beq   ASM_PFX(ArmPlatformSecondaryParking)
_PrimaryCore:
  mov   lr, r12
  bx    lr

//UINTN
//ArmPlatformGetPrimaryCoreMpId (
//  VOID
//  );
ASM_PFX(ArmPlatformGetPrimaryCoreMpId):
  LoadConstantToReg (_gPcd_FixedAtBuild_PcdArmPrimaryCore, r0)
  ldr    r0, [r0]
  bx     lr

//UINTN
//ArmPlatformIsPrimaryCore (
//  IN UINTN MpId
//  );
ASM_PFX(ArmPlatformIsPrimaryCore):
  mrc   p15, 0, r0, c0, c0, 5
  and   r0, r0, #0xff
  cmp   r0, #0
  moveq r0, #1
  movne r0, #0
  bx    lr

//UINTN
//ArmPlatformIsGicV2OrLower (
//  VOID
//  );
ASM_PFX(ArmPlatformIsGicV2OrLower):
  LoadConstantToReg (FixedPcdGet32 (PcdCpuGicDistributorBase), r1)
  ldr   r0, [r1, #0x4]
  and   r0, r0, #0x1f
  cmp   r0, #0x1f
  moveq r0, #0
  movne r0, #1
  bx    lr

//
// Park a secondary CPU in a WFI loop until the primary CPU writes a
// release address into this CPU's mailbox.
//
ASM_PFX(ArmPlatformSecondaryParking):
  mrc   p15, 0, r0, c0, c0, 5
  and   r0, r0, #0xff
  mov   r4, r0
  LoadConstantToReg (FixedPcdGet32 (PcdCpuMailboxBase), r5)
  add   r5, r5, r0, lsl #12
  LoadConstantToReg (FixedPcdGet32 (PcdCpuGicInterruptInterfaceBase), r1)
  mov   r2, #1
  str   r2, [r1, #0]
  mov   r2, #0xff
  str   r2, [r1, #4]
  str   r4, [r5, #0]
  mov   r2, #0
  str   r2, [r5, #8]
  dsb
  isb
1:
  wfi
  ldr   r3, [r5, #0]
  cmp   r3, r4
  bne   1b
  ldr   r3, [r5, #8]
  cmp   r3, #0
  beq   1b
  mov   r2, #0
  str   r2, [r5, #8]
  mrc   p15, 0, r0, c1, c0, 0
  bic   r0, r0, #1
  bic   r0, r0, #4
  bic   r0, r0, #0x1000
  mcr   p15, 0, r0, c1, c0, 0
  dsb
  isb
  msr   cpsr_c, #0xd3
  mov   r0, r5
  bx    r3

//UINTN
//ArmPlatformGetCorePosition (
//  IN UINTN MpId
//  );
// With this function: CorePos = (ClusterId * 4) + CoreId
ASM_PFX(ArmPlatformGetCorePosition):
  and   r1, r0, #ARM_CORE_MASK
  and   r0, r0, #ARM_CLUSTER_MASK
  add   r0, r1, r0, LSR #6
  bx    lr

//EFI_PHYSICAL_ADDRESS
//GetPhysAddrTop (
//  VOID
//  );
ASM_PFX(ArmGetPhysAddrTop):
  mov   r0, #0x00000000
  mov   r1, #0x10000
  bx    lr

ASM_FUNCTION_REMOVE_IF_UNREFERENCED
