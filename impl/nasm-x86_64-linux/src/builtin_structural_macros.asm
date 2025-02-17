section .text
global push_builtin_structural_macros

extern byte_buffer_push_barray
extern byte_buffer_push_barray_bytes
extern byte_buffer_push_bytes
extern byte_buffer_push_int64
extern byte_buffer_push_int32
extern byte_buffer_push_int16
extern byte_buffer_push_byte
extern byte_buffer_write_int64
extern byte_buffer_get_data_length
extern byte_buffer_get_buf
extern byte_buffer_extend

extern macro_stack_push_range
extern macro_stack_push
extern macro_stack_pop

extern macro_stack_structural

section .rodata

barray_test_macro_name: db 11,0,0,0,0,0,0,0,"barray-test"
parray_test_macro_name: db 11,0,0,0,0,0,0,0,"parray-test"
nothing_macro_name: db 7,0,0,0,0,0,0,0,"nothing"
push_macro_macro_name: db 10,0,0,0,0,0,0,0,"push-macro"
pop_macro_macro_name: db 9,0,0,0,0,0,0,0,"pop-macro"
elf64_relocatable_macro_name: db 17,0,0,0,0,0,0,0,"elf64-relocatable"

barray_literal_macro_name: db 17,0,0,0,0,0,0,0,"test_macro_barray"
barray_test_expansion: db 17,0,0,0,0,0,0,0,"test_macro_barray"

parray_element: db 3,0,0,0,0,0,0,0,"foo"
parray_element_2: db 4,0,0,0,0,0,0,0,"foo2"
parray_element_3: dq -2,barray_test_macro_name
parray_test_expansion: dq -4,parray_element,parray_element_2,parray_element_3

section .text

;;; push_builtin_structural_macros()
;;;   Pushes builtin structural macros to the structural macro stack
push_builtin_structural_macros:
  sub rsp, 8

  ;; Push barray-test macro
  mov rdi, qword[macro_stack_structural]   ; macro stack
  mov rsi, barray_test_macro_name          ; macro name
  mov rdx, barray_test                     ; code
  mov rcx, (barray_test_end - barray_test) ; length
  call macro_stack_push_range

  ;; Push parray-test macro
  mov rdi, qword[macro_stack_structural]   ; macro stack
  mov rsi, parray_test_macro_name          ; macro name
  mov rdx, parray_test                     ; code
  mov rcx, (parray_test_end - parray_test) ; length
  call macro_stack_push_range

  ;; Push nothing macro
  mov rdi, qword[macro_stack_structural]   ; macro stack
  mov rsi, nothing_macro_name          ; macro name
  mov rdx, nothing                     ; code
  mov rcx, (nothing_end - nothing) ; length
  call macro_stack_push_range


  ;; Push push_macro macro
  mov rdi, qword[macro_stack_structural]   ; macro stack
  mov rsi, push_macro_macro_name          ; macro name
  mov rdx, push_macro                     ; code
  mov rcx, (push_macro_end - push_macro) ; length
  call macro_stack_push_range

  ;; Push pop_macro macro
  mov rdi, qword[macro_stack_structural]   ; macro stack
  mov rsi, pop_macro_macro_name          ; macro name
  mov rdx, pop_macro                     ; code
  mov rcx, (pop_macro_end - pop_macro) ; length
  call macro_stack_push_range

  ;; Push elf64_relocatable macro
  mov rdi, qword[macro_stack_structural]   ; macro stack
  mov rsi, elf64_relocatable_macro_name          ; macro name
  mov rdx, elf64_relocatable                     ; code
  mov rcx, (elf64_relocatable_end - elf64_relocatable) ; length
  call macro_stack_push_range

  add rsp, 8
  ret

;;; barray_test(*structure, *output_byte_buffer) -> output buf relative pointer
;;;   Test macro that produces a static barray
barray_test:
  push r12
  push r13
  sub rsp, 8

  mov r12, rdi ; input structure
  mov r13, rsi ; output byte buffer

  mov rdi, r13
  mov rsi, barray_test_expansion
  mov rax, byte_buffer_push_barray
  call rax

  mov rax, 0
  add rsp, 8
  pop r13
  pop r12
  ret
barray_test_end:

;;; parray_test(*structure, *output_byte_buffer) -> output buf relative pointer
;;;   Test macro that produces a static parray
parray_test:
  push r12
  push r13
  sub rsp, 8

  mov r12, rdi ; input structure
  mov r13, rsi ; output byte buffer

  mov rdi, r13
  mov rsi, parray_test_expansion
  mov rdx, (8 * 4)
  mov rax, byte_buffer_push_bytes
  call rax

  mov rax, 0
  add rsp, 8
  pop r13
  pop r12
  ret
parray_test_end:

;;; nothing(*structure, *output_byte_buffer) -> output buf relative pointer
;;;   macro that expands into nothing
nothing:
  mov rax, -1
  ret

nothing_end:

;;; push_macro(*structure, *output_byte_buffer) -> output buf relative pointer
;;;   Macro with a side-effect of pushing a new macro onto the structural
;;;   macro stack. Expands to nothing.
push_macro:
  push r12

  mov r12, rdi ; structure
  ;; TODO error if wrong parameter count
  ;; TODO error if parameters aren't barrays

  mov rdi, qword[macro_stack_structural]
  mov rsi, qword[r12+16]
  mov rdx, qword[r12+24]
  mov rax, macro_stack_push
  call rax

  mov rax, -1
  pop r12
  ret
push_macro_end:


;;; pop_macro(*structure, *output_byte_buffer) -> output buf relative pointer
;;;   Macro with a side-effect of popping a macro off the structural macro
;;;   stack. Expands to nothing.
pop_macro:
  push r12

  mov r12, rdi ; structure

  ;; TODO if an argument is specified, do pop-by-name

  mov rdi, qword[macro_stack_structural]
  mov rax, macro_stack_pop
  call rax

  mov rax, -1
  pop r12
  ret

pop_macro_end:

;;; elf64_relocatable(*structure, *output_byte_buffer) -> output buf relative ptr
;;;   Macro for producing a relocatable (.o) elf64 file. Expands to a barray.
;;; TODO should this just be elf_relocatable and not be written to be
;;; 64-bit specific?
;;; TODO should this just be 'elf' and not relocatable specific?
;;; TODO should this be a builtin macro? might be fine to just be implemented in aarrp as a lib
elf64_relocatable:
  push rbp
  push r12
  push r13
  push r14
  sub rsp, 8
  mov rbp, rsp

  mov r12, rdi ; structure
  mov r13, rsi ; output byte buffer

  ;; Push a barray length placeholder
  mov rdi, r13
  mov rsi, 0
  mov rax, byte_buffer_push_int64
  call rax

  ;; Make room for elf header in byte buffer
  mov rdi, r13
  mov rsi, 64
  mov rax, byte_buffer_extend
  call rax

  ;; Grab pointer to backing buffer
  mov rdi, r13
  mov rax, byte_buffer_get_buf
  call rax
  mov r14, rax

  add r14, 8 ; Move past length

  ;; Write ELF header
  mov dword[r14], 0x464C457F ; magic
  mov byte[r14+4], 2         ; EI_CLASS (we're 64 bit)
  mov byte[r14+5], 1         ; EI_DATA (1 = little endian) TODO accept arg?
  mov byte[r14+6], 1         ; EI_VERSION
  mov byte[r14+7], 3         ; EI_OSABI - Static 'linux' for now TODO accept arg?
  mov byte[r14+8], 0         ; EI_ABIVERSION
  mov dword[r14+9], 0        ; +4 padding
  mov word[r14+13], 0        ; +2 padding
  mov byte[r14+15], 0        ; +1 padding
  mov word[r14+16], 1        ; e_type - We're a relocatable file
  mov word[r14+18], 62       ; e_machine - We're amd64. TODO accept arg?
  mov dword[r14+20], 1       ; e_version
  mov qword[r14+24], 0       ; e_entry - 0 because we're not an executable
  mov qword[r14+32], 0       ; e_phoff - 0 because we're not an executable
  mov qword[r14+40], 64      ; e_shoff - section table offset TODO placeholder
  mov dword[r14+48], 0       ; e_flags - cpu-specific flags TODO accept arg?
  mov word[r14+52], 64       ; e_ehsize - size of this ELF header
  mov word[r14+54], 0        ; e_phentsize - size of each program header entry
  mov word[r14+56], 0        ; e_phnum - 0 because we're not an executable
  mov word[r14+58], 64       ; e_shentsize - size of each section header entry
  mov word[r14+60], 0        ; e_shnum - Number of sections TODO placeholder
  mov word[r14+62], 0        ; e_shstrndx - Index of str table in section table TODO placeholder

  ;; Update barray length with our byte buffer's data length
  mov rdi, r13
  mov rax, byte_buffer_get_data_length
  call rax

  mov rdi, r13
  mov rsi, 0
  mov rdx, rax
  sub rdx, 8
  mov rax, byte_buffer_write_int64
  call rax

  mov rax, 0
  mov rsp, rbp
  add rsp, 8
  pop r14
  pop r13
  pop r12
  pop rbp
  ret

elf64_relocatable_end:
