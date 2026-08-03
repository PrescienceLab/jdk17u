// #if defined(RAFTV64)
// # define LREG ld
// # define SREG sd
// # define REGBYTES 8
// #elif defined(RAFTV32)
// # define LREG lw
// # define SREG sw
// # define REGBYTES 4
// #else
// # error "KBEs only work on RAFT-V CPUs!"
// #endif

#include "csr.h"

#define LREG ld
#define SREG sd
#define REGBYTES 8

/* Read from the cycle counter and stash it into USCRATCH. We must be careful
 * about which integer register we clobber here and the manner in which we do it
 * so that we do not destroy any state unnecessarily. We MUST clobber an integer
 * register since there are no instructions to transfer a value from one CSR to
 * another CSR in RISC-V.
 * STEPS:
 * 1. uscratch <- x1 for safe keeping
 * 2. x1 <- cycles
 * 3. x1 <- uscratch (stashed x1) AND SIMULTANEOUSLY
 *    uscratch <- x1 (cycle count) */
  .macro CYCLES_TO_USCRATCH
  csrw CSR_USCRATCH, x1
  rdcycle x1
  csrrw x1, CSR_USCRATCH, x1
  .endm

  .global kbe_handler_entry
  .align 2
  .type kbe_handler_entry, @function
kbe_handler_entry:
  .cfi_startproc
  /* NOTE: This rdcycle should NOT be in the final handler implementation. We
   * only need it here for timing the inst->handler->next-inst sequence. */
  // CYCLES_TO_USCRATCH

  addi sp, sp, -272
  .cfi_adjust_cfa_offset 272
  // CFA pointing to BASE (LOWEST ADDRESS) of the stack entry.

  /* Saved in setup for frame pointer walking in GDB. */
  SREG ra, 33*REGBYTES(sp)
  SREG fp, 32*REGBYTES(sp) /* NOTE: $fp = $s0 = $x8 */

  .cfi_offset ra, -264 // -33*REGBYTES(sp)
  .cfi_offset fp, -256 // -32*REGBYTES(sp)

  /* We need to move this frame pointer to point to the base of OUR "call frame"
   * when using -fno-omit-frame-pointer to make things behave correctly in later
   * C code. However, we should NOT expose this modified fp to the KBE handler
   * as that will not line up with the ucontext's expected GREGs contents. So we
   * save the fp register early and then move it for later C code. */
  SREG fp, 8*REGBYTES(sp)
  addi fp, sp, 272 /* $fp = $s0 = $x8 */
  .cfi_def_cfa fp, 0

  SREG x1, 1*REGBYTES(sp)
  SREG x2, 2*REGBYTES(sp)
  SREG x3, 3*REGBYTES(sp)
  SREG x4, 4*REGBYTES(sp)
  SREG x5, 5*REGBYTES(sp)
  SREG x6, 6*REGBYTES(sp)
  SREG x7, 7*REGBYTES(sp)
  // SREG x8, 8*REGBYTES(sp) // Saved earlier for frame pointer reasons
  SREG x9, 9*REGBYTES(sp)
  SREG x10, 10*REGBYTES(sp)
  SREG x11, 11*REGBYTES(sp)
  SREG x12, 12*REGBYTES(sp)
  SREG x13, 13*REGBYTES(sp)
  SREG x14, 14*REGBYTES(sp)
  SREG x15, 15*REGBYTES(sp)
  SREG x16, 16*REGBYTES(sp)
  SREG x17, 17*REGBYTES(sp)
  SREG x18, 18*REGBYTES(sp)
  SREG x19, 19*REGBYTES(sp)
  SREG x20, 20*REGBYTES(sp)
  SREG x21, 21*REGBYTES(sp)
  SREG x22, 22*REGBYTES(sp)
  SREG x23, 23*REGBYTES(sp)
  SREG x24, 24*REGBYTES(sp)
  SREG x25, 25*REGBYTES(sp)
  SREG x26, 26*REGBYTES(sp)
  SREG x27, 27*REGBYTES(sp)
  SREG x28, 28*REGBYTES(sp)
  SREG x29, 29*REGBYTES(sp)
  SREG x30, 30*REGBYTES(sp)
  SREG x31, 31*REGBYTES(sp)

  /* With all GREGS saved, we also need to save the PC of the instruction that
   * faulted to the 0th index of the stack, to match up with what mcontext's
   * gregs expect. On RISC-V GREG x0 (the zero register) is hardwired to zero,
   * so we do not need to save it. Instead, we can stash PC there instead.
   * FIXME: If we only use PC passed through the GREGS structure on the stack,
   * then we MUST reload this value off the stack, instead of having handle_ppe
   * return a new UEPC. */
  csrr a1, 0x841 // uepc
  SREG a1, 0*REGBYTES(sp)

  csrr a0, 0x842 // ucause
  mv a2, sp
  /* Relocations in the compiler and linker required us to switch to a lr+jalr
   * setup. */
  la ra, javaSignalHandler_kbeShim
  jalr ra, ra, 0
  csrw 0x841 /* uepc */, a0

  /* XXX: We do NOT restore the ra & fp we saved on the stack! We want the
   * modifications the user made to the mcontext's GREGs to show up in the
   * core upon returning, so we just deallocate those values by popping the
   * stack frame.
   *
   * We also do NOT do anything to move the fp <- sp + 272 because we saved the
   * original version of fp before we did that movement. */

  LREG x1, 1*REGBYTES(sp) // ra
  .cfi_restore ra
  LREG x2, 2*REGBYTES(sp)
  LREG x3, 3*REGBYTES(sp)
  LREG x4, 4*REGBYTES(sp)
  LREG x5, 5*REGBYTES(sp)
  LREG x6, 6*REGBYTES(sp)
  LREG x7, 7*REGBYTES(sp)
  LREG x8, 8*REGBYTES(sp) // fp/s0
  .cfi_restore fp
  LREG x9, 9*REGBYTES(sp)
  LREG x10, 10*REGBYTES(sp)
  LREG x11, 11*REGBYTES(sp)
  LREG x12, 12*REGBYTES(sp)
  LREG x13, 13*REGBYTES(sp)
  LREG x14, 14*REGBYTES(sp)
  LREG x15, 15*REGBYTES(sp)
  LREG x16, 16*REGBYTES(sp)
  LREG x17, 17*REGBYTES(sp)
  LREG x18, 18*REGBYTES(sp)
  LREG x19, 19*REGBYTES(sp)
  LREG x20, 20*REGBYTES(sp)
  LREG x21, 21*REGBYTES(sp)
  LREG x22, 22*REGBYTES(sp)
  LREG x23, 23*REGBYTES(sp)
  LREG x24, 24*REGBYTES(sp)
  LREG x25, 25*REGBYTES(sp)
  LREG x26, 26*REGBYTES(sp)
  LREG x27, 27*REGBYTES(sp)
  LREG x28, 28*REGBYTES(sp)
  LREG x29, 29*REGBYTES(sp)
  LREG x30, 30*REGBYTES(sp)
  LREG x31, 31*REGBYTES(sp)

  addi sp, sp, 272
  .cfi_def_cfa sp, 0

  /* Like at the start of this ASM procedure, we capture the time we leave this
   * handler right before we execute the URET, so that we can measure the time
   * required for us to jump back to the location we specified in uepc above. */
  // CYCLES_TO_USCRATCH

  uret
  .cfi_endproc
