section .text
global push_builtin_structural_macros

extern byte_buffer_push_barray
extern byte_buffer_push_barray_bytes
extern byte_buffer_push_bytes
extern byte_buffer_push_int64
extern byte_buffer_push_int32
extern byte_buffer_push_int16
extern byte_buffer_push_byte
extern byte_buffer_push_byte_n_times
extern byte_buffer_write_int64
extern byte_buffer_get_data_length
extern byte_buffer_get_buf
extern byte_buffer_extend
extern write
extern write_as_base
extern compare_barrays
extern print
extern error_exit

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
barray_name: db 4,0,0,0,0,0,0,0,"name"
shstrtab_name: db 9,0,0,0,0,0,0,0,".shstrtab"

parray_element: db 3,0,0,0,0,0,0,0,"foo"
parray_element_2: db 4,0,0,0,0,0,0,0,"foo2"
parray_element_3: dq -2,barray_test_macro_name
parray_test_expansion: dq -4,parray_element,parray_element_2,parray_element_3

sections_str: db 8,0,0,0,0,0,0,0,"sections"

barray_error: db "ERROR: Got barray in section, expecting parrays only",10
barray_error_len:  equ $ - barray_error

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


;;; _elf64_relocatable_find_sections_parray(structure*)
;;;   Returns a pointer to the sections parray of an elf64-relocatable macro call
;;;
;;;   Returns NULL if not found/doesn't exist.
_elf64_relocatable_find_sections_parray:
  push r12
  push r13
  push r14
  push r15
  sub rsp, 8

  mov r12, rdi        ; structure
  mov r13, qword[r12] ; count of top level parray
  not r13             ; one's complement to get correct count
  mov r15, 0          ; return value, will be NULL if we don't find it
  add r12, 8          ; move past length

  .find_sections_loop:
    mov r14, qword[r12] ; r14 = pointer to this item

    ;; Skip this item if it's a barray
    cmp qword[r14], 0
    jge .find_sections_next

    ;; Skip this item if it's an empty parray
    cmp qword[r14], -1
    je .find_sections_next

    ;; Skip this item if the first element is not "sections".
    mov rdi, sections_str
    mov rsi, qword[r14+8]
    call compare_barrays
    cmp rax, 0
    je .find_sections_next

    ;; Save pointer to sections parray
    mov r15, r14

    .find_sections_next:
    add r12, 8 ; Next pointer in parray
    dec r13
    cmp r13, 0
    jne .find_sections_loop


  mov rax, r15
  add rsp, 8
  pop r15
  pop r14
  pop r13
  pop r12
  ret

;;; _elf64_relocatable_write_section_header(section_parray*, output_byte_buffer*)
;;;   Writes an encoded section header to the output byte buffer from the input section parray
_elf64_relocatable_write_section_header:
  push r12
  push r13
  push r14
  push r15
  sub rsp, 8

  mov r12, rdi ; section parray
  mov r13, rsi ; output byte buffer

  ;; Write out a NULL header, we'll fill it with real values later
  mov rdi, r13
  mov rsi, 0
  mov rdx, 64
  call byte_buffer_push_byte_n_times

  ;; Iterate over elements of section
  mov r14, qword[r12] ; r14 = count
  not r14
  add r12, 8 ; Move past length
  .els:
    mov r15, qword[r12] ;; r15 = pointer to this element

    ;; Error if this element is a barray
    cmp qword[r15], 0
    jl .not_barray
    mov rdi, barray_error
    mov rsi, barray_error_len
    call error_exit
    .not_barray:

    ;; TODO update header data with relevant info from this parray (at r15)

    add r12, 8
    dec r14
    cmp r14, 0
    jne .els


  add rsp, 8
  pop r15
  pop r14
  pop r13
  pop r12
  ret

;;; _elf64_relocatable_write_section_headers(sections_parray*, output_byte_buffer*)
;;;   Writes the elf64 section headers specified in the sections parray
_elf64_relocatable_write_section_headers:
  push r12
  push r13
  push r14
  push r15
  sub rsp, 8

  mov r12, rdi ; sections parray
  mov r13, rsi ; output byte buffer

  ;; Write the NULL section header
  mov rdi, r13
  mov rsi, 0
  mov rdx, 64
  call byte_buffer_push_byte_n_times

  ;; Write the strtab section header
  ;; TODO alignment field in header?

  ; name, will always be at index 1 for shstrtab
  mov rdi, r13
  mov rsi, 1
  call byte_buffer_push_int32

  ; type - STRTAB (3)
  mov rdi, r13
  mov rsi, 3
  call byte_buffer_push_int32

  ; everything else NULL for now (offset and size will be set later)
  mov rdi, r13
  mov rsi, 0
  mov rdx, 56
  call byte_buffer_push_byte_n_times

  ;; If sections parray is NULL, we're done
  cmp r12, 0
  je .epilogue

  mov r14, qword[r12] ; r14 = section count
  not r14
  dec r14 ; exclude "sections" barray

  add r12, 16 ; move past length and first barray
  .section_loop:
    cmp r14, 0
    je .section_loop_break

    mov r15, qword[r12] ; r15 = section

    mov rdi, r15
    mov rsi, r13
    call _elf64_relocatable_write_section_header

    add r12, 8 ; next section
    dec r14
    jmp .section_loop

  .section_loop_break:

  .epilogue:
  add rsp, 8
  pop r15
  pop r14
  pop r13
  pop r12
  ret

;;; TODO
;;; _elf64_relocatable_write_section_name(section_parray*, output_byte_buffer*)
_elf64_relocatable_write_section_name:
  push r12
  push r13
  push r14
  push r15
  push rbx

  mov r12, rdi
  mov r13, rsi

  ;; TODO if section parray is NULL, just return

  mov r14, qword[r12] ; r14 = element count
  not r14

  ;; TODO iterate over elements of section
  add r12, 8 ; move past length
  .els:
    cmp r14, 0
    mov rax, 0
    je .els_break

    ;; TODO error if this element is a barray

    mov r15, qword[r12] ; r15 = parray pointer to this attribute

    ;mov rdi, r15
    ;mov rsi, 2
    ;call print

    ;; If this parray has less than 2 elements, go to the next element
    mov rbx, qword[r15] ; rbx = element count
    not rbx
    cmp rbx, 2
    jl .next_el

    ;mov rdi, rbx
    ;mov rsi, 10
    ;mov rdx, 2
    ;mov rcx, 0
    ;call write_as_base

    ;; Check if this parray starts with "name"
    add r15, 8 ; move past length

    mov rdi, qword[r15]
    mov rsi, barray_name
    call compare_barrays
    cmp rax, 0
    je .next_el

    ;mov rdi, barray_name
    ;mov rsi, 2
    ;call print

    ;; It's name, write the name then break the loop
    add r15, 8 ; move to 2nd element

    mov rax, qword[r15]
    mov rax, qword[rax] ; rax = size of string we'll write including NULL
    inc rax

    push rax
    sub rsp, 8

    mov rdi, r13          ; rdi = output byte buffer
    mov rsi, qword[r15] ; rsi = 2nd parray element (the name)
    call byte_buffer_push_barray_bytes

    ;; Write NULL terminator
    mov rdi, r13
    mov rsi, 0
    call byte_buffer_push_byte

    add rsp, 8
    pop rax

    jmp .els_break

    .next_el:
    add r12, 8
    dec r14
    jmp .els

  .els_break:

  .epilogue:
  pop rbx
  pop r15
  pop r14
  pop r13
  pop r12
  ret

;;; _elf64_relocatable_write_shstrtab(sections_parray*, output_byte_buffer*)
;;;   Writes section header string tabulation for the given sections
_elf64_relocatable_write_shstrtab:
  push r12
  push r13
  push r14
  push r15
  push rbx

  mov r12, rdi
  mov r13, rsi

  ;; Write leading NULL
  mov rdi, r13
  mov rsi, 0
  call byte_buffer_push_byte

  ;; Write .shstrtab name
  mov rdi, r13
  mov rsi, shstrtab_name
  call byte_buffer_push_barray_bytes

  ;; Write .shstrtab NULL terminator
  mov rdi, r13
  mov rsi, 0
  call byte_buffer_push_byte

  ;; Return if sections parray is NULL
  cmp r12, 0
  je .epilogue

  mov r14, qword[r12] ; r14 = section count
  not r14
  dec r14 ; exclude "sections" barray

  ;; Grab pointer to section headers
  mov rdi, r13
  mov rax, byte_buffer_get_buf
  call rax
  mov r8, rax

  add r8, 8  ; Move past length
  add r8, 64 ; Move past header


  ;; Iterate over sections
  add r12, 16  ; move past length and first barray
  mov r15, 128 ; offset of first section header past .shstrtab
  mov rbx, 11  ; index of first string past .shstrtab
  .section_loop:
    cmp r14, 0
    je .section_loop_break

    push r8
    sub rsp, 8

    mov rdi, qword[r12] ; rdi = pointer to section
    mov rsi, r13
    call _elf64_relocatable_write_section_name

    add rsp, 8
    pop r8

    ;; Update section header with name
    cmp rax, 0
    je .no
    mov dword[r8+r15], ebx
    .no:
    add rbx, rax ;; rbx += section name length

    add r15, 64
    add r12, 8
    dec r14
    jmp .section_loop

  .section_loop_break:

  .epilogue:
  pop rbx
  pop r15
  pop r14
  pop r13
  pop r12
  ret

;;; _elf64_relocatable_pad_to_nearest(output_byte_buffer*, to)
;;;   Pads output buffer (with zero) to the nearest specified value for alignment purposes
;;;
;;;   'to' must be a power of 2, otherwise undefined behavior
_elf64_relocatable_pad_to_nearest:
  push r12
  push r13
  push r14

  mov r13, rdi
  mov r12, rsi

  ;; Get current loc
  mov rdi, r13
  call byte_buffer_get_data_length
  sub rax, 8 ; remove barray length


  ;; Determine how much to add
  dec r12
  and rax, r12

  mov rcx, 16
  sub rcx, rax

  cmp rcx, 16
  je .epilogue

  ;; Add padding
  mov rdi, r13
  mov rsi, 0
  mov rdx, rcx
  call byte_buffer_push_byte_n_times

  .epilogue:
  pop r14
  pop r13
  pop r12
  ret

;;; elf64_relocatable(structure*, output_byte_buffer*) -> output buf relative ptr
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
  push r15
  push rbx
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
  mov word[r14+60], 1        ; e_shnum - Number of sections TODO placeholder
  mov word[r14+62], 1        ; e_shstrndx - Index of str table in section table TODO placeholder

  ;; Find sections parray in input structure
  mov rdi, r12
  mov rax, _elf64_relocatable_find_sections_parray
  call rax
  mov r15, rax

  ;; write section count to header
  cmp r15, 0
  mov rdi, 1
  je .null_sections
  mov rdi, qword[r15]
  not rdi
  .null_sections:
  inc di ;; add 1 for string tab
  mov word[r14+60], di

  ;; write section headers
  mov rdi, r15
  mov rsi, r13
  mov rax, _elf64_relocatable_write_section_headers
  call rax

  ;; Update section header to point to where the shstrtab will be
  mov rdi, r13
  mov rax, byte_buffer_get_data_length
  call rax
  mov rbx, rax
  sub rbx, 8 ; remove barray length
  mov qword[r14+152], rbx

  ;; Write section header string tabulation
  mov rdi, r15
  mov rsi, r13
  mov rax, _elf64_relocatable_write_shstrtab
  call rax

  ;; Pad to nearest 16 byte boundary
  mov rdi, r13
  mov rsi, 16
  mov rax, _elf64_relocatable_pad_to_nearest
  call rax

  ;; Update section header to specify size of shstrtab
  mov rdi, r13
  mov rax, byte_buffer_get_data_length
  call rax
  sub rax, 8 ; remove barray length
  sub rax, rbx
  mov qword[r14+160], rax

  ;; TODO write section data (TODO alignment?)

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
  pop rbx
  pop r15
  pop r14
  pop r13
  pop r12
  pop rbp
  ret

elf64_relocatable_end:
