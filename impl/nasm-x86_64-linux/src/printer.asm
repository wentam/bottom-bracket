section .text
global fn_print
extern fn_assert_stack_aligned
extern fn_write_char
extern fn_write

section .rodata

section .text

;; aprint(*aarrp_expression, fd)
fn_print:
  push r12
  push r13
  push r15
  mov r12, rdi ; aarrp expression data
  mov r13, rsi ; fd

  %ifdef ASSERT_STACK_ALIGNMENT
  call fn_assert_stack_aligned
  %endif

  mov r15, qword[r12] ; r15 = length of array/atom

  cmp r15, 0
  jge aprint_atom

  neg r15

  add r12, 8 ; Move past array length

  mov rdi, '('
  mov rsi, r13
  call fn_write_char

  aprint_array_loop:
    cmp r15, 0
    je aprint_array_done

    mov rdi, qword[r12]
    mov rsi, r13
    call fn_print

    cmp r15, 1
    je nospace

    mov rdi, ' '
    mov rsi, r13
    call fn_write_char

    nospace:

    add r12, 8
    dec r15
    jmp aprint_array_loop

  aprint_array_done:

  mov rdi, ')'
  mov rsi, r13
  call fn_write_char
  jmp aprint_epilogue

  aprint_atom:
  add r12, 8 ; Move past length

  mov rdi, r12
  mov rsi, r15
  mov rdx, r13
  call fn_write

  aprint_epilogue:
  pop r15
  pop r13
  pop r12
  ret
