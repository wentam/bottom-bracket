section .text
global print
extern assert_stack_aligned
extern write_char
extern write

section .rodata

section .text

;; print(*aarrp_expression, fd)
print:
  push r12
  push r13
  push r15
  mov r12, rdi ; aarrp expression data
  mov r13, rsi ; fd

  %ifdef ASSERT_STACK_ALIGNMENT
  call assert_stack_aligned
  %endif

  mov r15, qword[r12] ; r15 = length of parray/barray

  cmp r15, 0
  jge .barray

  not r15

  add r12, 8 ; Move past parray length

  mov rdi, '('
  mov rsi, r13
  call write_char

  .parray_loop:
    cmp r15, 0
    je .parray_done

    mov rdi, qword[r12]
    mov rsi, r13
    call print

    cmp r15, 1
    je .nospace

    mov rdi, ' '
    mov rsi, r13
    call write_char

    .nospace:

    add r12, 8
    dec r15
    jmp .parray_loop

  .parray_done:

  mov rdi, ')'
  mov rsi, r13
  call write_char
  jmp .epilogue

  .barray:
  add r12, 8 ; Move past length

  mov rdi, r12
  mov rsi, r15
  mov rdx, r13
  call write

  .epilogue:
  pop r15
  pop r13
  pop r12
  ret
