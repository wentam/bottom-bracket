;; TODO: all builtin macros should be prefixed with aarrp/
;; TODO: make sure macros always use the mov rax, foo; call foo pattern.
;;       call foo uses relative addresses, the above pattern uses absolute.
;;       Do this even if 'call foo' seems to work, as any time a macro moves
;;       this will eventually break.

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
extern byte_buffer_new
extern byte_buffer_free
extern structural_macro_expand
extern structural_macro_expand_tail
extern write
extern write_as_base
extern compare_barrays
extern print
extern error_exit
extern parray_tail_new
extern free

extern macro_stack_push_range
extern macro_stack_push
extern macro_stack_pop

extern macro_stack_structural

section .rodata

barray_test_macro_name: db 11,0,0,0,0,0,0,0,"barray-test"
parray_test_macro_name: db 11,0,0,0,0,0,0,0,"parray-test"
nothing_macro_name: db 7,0,0,0,0,0,0,0,"nothing"
elf64_relocatable_macro_name: db 17,0,0,0,0,0,0,0,"elf64-relocatable"
barray_cat_macro_name: db 16,0,0,0,0,0,0,0,"aarrp/barray-cat"
with_macros_macro_name: db 17,0,0,0,0,0,0,0,"aarrp/with-macros"

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

cat_parray_error: db "ERROR: Got parray in aarrp/barray-cat, expecting barrays only",10
cat_parray_error_len:  equ $ - cat_parray_error

;;; Stuff for with-macros macro:

with_macros_need_parray_error: db "ERROR: Got barray for the macro list in aarrp/with-macros. Must be parray of macro specifiers.",10
with_macros_need_parray_error_len:  equ $ - with_macros_need_parray_error

with_macros_need_parray_2_error: db "ERROR: Got barray for a macro specifier in aarrp/with-macros. Must be parray like (my-macro (my-platform machine-code)).",10
with_macros_need_parray_2_error_len:  equ $ - with_macros_need_parray_2_error

with_macros_name_not_barray_error: db "ERROR: Got parray instead of barray for macro name in aarrp/with-macros. Should be barray.",10
with_macros_name_not_barray_error_len:  equ $ - with_macros_name_not_barray_error

with_macros_spec_too_short_error: db "ERROR: Macro spec too short for a macro in aarrp/with-macros. Should have at least 2 elements: (macro-name (platform-1 machine-code-1))",10
with_macros_spec_too_short_error_len:  equ $ - with_macros_spec_too_short_error

with_macros_impl_spec_not_parray_error: db "ERROR: Got barray for implementation specifier in aarrp/with-macros. Should be parray like (my-platform machine-code).",10
with_macros_impl_spec_not_parray_error_len:  equ $ - with_macros_impl_spec_not_parray_error

with_macros_impl_spec_wrong_len_error: db "ERROR: Implementation specifier wrong length in aarrp/with-macros. Should be two barray elements like (platform machine-code).",10
with_macros_impl_spec_wrong_len_error_len:  equ $ - with_macros_impl_spec_wrong_len_error

with_macros_impl_spec_platform_not_barray_error: db "ERROR: First element of implementation specifier in aarrp/with-macros is not a barray. Should be a barray of the platform name like x86_64-linux."
with_macros_impl_spec_platform_not_barray_error_len:  equ $ - with_macros_impl_spec_platform_not_barray_error

with_macros_impl_spec_machine_code_not_barray_error: db "ERROR: Second element of implementation specifier in aarrp/with-macros is not a barray. Should be a barray of machine code for the given platform.",10
with_macros_impl_spec_machine_code_not_barray_error_len:  equ $ - with_macros_impl_spec_machine_code_not_barray_error

with_macros_unsupported_platform_error: db "ERROR: Attempt to expand a macro that doesn't have an implementation for a platform we support. Supported platforms: x86_64-linux."
with_macros_unsupported_platform_error_len: equ $ - with_macros_unsupported_platform_error

with_macros_supported_platform_barray: db 12,0,0,0,0,0,0,0,"x86_64-linux"

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

  ;; Push elf64_relocatable macro
  mov rdi, qword[macro_stack_structural]   ; macro stack
  mov rsi, elf64_relocatable_macro_name          ; macro name
  mov rdx, elf64_relocatable                     ; code
  mov rcx, (elf64_relocatable_end - elf64_relocatable) ; length
  call macro_stack_push_range


  ;; Push barray-cat macro
  mov rdi, qword[macro_stack_structural]  ; macro stack
  mov rsi, barray_cat_macro_name          ; macro name
  mov rdx, barray_cat                     ; code
  mov rcx, (barray_cat_end - barray_cat)  ; length
  call macro_stack_push_range

  ;; Push with-macros macro
  mov rdi, qword[macro_stack_structural]  ; macro stack
  mov rsi, with_macros_macro_name          ; macro name
  mov rdx, with_macros                    ; code
  mov rcx, (with_macros_end - with_macros)  ; length
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
;;; TODO: macroexpand all children like aarrp/barray-cat does
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


;;; aarrp/barray-cat

;;; barray_cat(structure*, output_byte_buffer*) -> output buf relative ptr
barray_cat:
  push r12
  push r13
  push r14
  push r15
  push rbx

  mov r12, rdi ; input structure
  mov r13, rsi ; output byte buffer

  ;; Macroexpand tail of our input
  mov rax, byte_buffer_new
  call rax
  mov r14, rax ; r14 = macroexpansion backing buffer

  mov rdi, r12
  mov rsi, r14
  mov rdx, 2 ; greedy expand
  mov rax, structural_macro_expand_tail
  call rax
  mov r12, rax ; r12 = macroexpanded tail of input structure

  ;; Push a length placeholder
  mov rdi, r13
  mov rsi, 0
  mov rax, byte_buffer_push_int64
  call rax

  ;; Iterate over children and build our output
  mov rbx, qword[r12]
  not rbx

  mov r8, r12
  add r8, 8 ; move past length
  mov r9, 0 ; byte counter

  .concat_loop:
  cmp rbx, 0
  je .concat_loop_break

  ;; If our input item is not a barray, error and exit
  mov rdi, qword[r8]
  cmp qword[rdi], 0
  jge .is_barray

  mov rdi, cat_parray_error
  mov rsi, cat_parray_error_len
  mov rax, error_exit
  call rax

  .is_barray:

  mov rdi, qword[r8]
  add r9, qword[rdi]

  mov rdi, r13
  mov rsi, qword[r8]
  mov rax, byte_buffer_push_barray_bytes
  push r8
  push r9
  call rax
  pop r9
  pop r8

  add r8, 8
  dec rbx
  jmp .concat_loop

  .concat_loop_break:

  ;; Update output length
  mov rdi, r13
  mov rsi, 0
  mov rdx, r9
  mov rax, byte_buffer_write_int64
  call rax

  ;; Free our macroexpansion
  mov rdi, r14
  mov rax, byte_buffer_free
  call rax

  mov rax, 0
  pop rbx
  pop r15
  pop r14
  pop r13
  pop r12
  ret
barray_cat_end:

;;; _with_macros_try_push_impl(macro_name_barray*, impl_spec*)
;;;   Attempts to push a macro implementation spec to the structural macro stack
;;;
;;;   Undefined behavior if impl_spec* isn't a parray.
;;;   Undefined behavior if macro_name_barray* isn't a barray.
;;;
;;;   Returns 1 on success, 0 on failure.
_with_macros_try_push_impl:
  push r12
  push r13
  push r14

  mov r12, rdi ; r12 = macro name barray
  mov r13, rsi ; r13 = impl_spec* parray

  ;; Error if impl_spec* parray has anything other than 2 elements
  mov rdi, qword[r13]
  not rdi
  cmp rdi, 2
  je .correct_spec_len

  mov rdi, with_macros_impl_spec_wrong_len_error
  mov rsi, with_macros_impl_spec_wrong_len_error_len
  call error_exit

  .correct_spec_len:

  ;; Error if the first element of impl_spec* parray isn't a barray (to name the platform)
  mov rdi, qword[r13+8]
  mov rsi, qword[rdi]
  cmp rsi, 0
  jge .platform_is_barray

  mov rdi, with_macros_impl_spec_platform_not_barray_error
  mov rsi, with_macros_impl_spec_platform_not_barray_error_len
  call error_exit

  .platform_is_barray:

  ;; Error if the second element of the impl_spec* parray isn't a barray (specifying machine code)
  mov rdi, qword[r13+16]
  mov rsi, qword[rdi]
  cmp rsi, 0
  jge .code_is_barray

  mov rdi, with_macros_impl_spec_machine_code_not_barray_error
  mov rsi, with_macros_impl_spec_machine_code_not_barray_error_len
  call error_exit

  .code_is_barray:

  ;; If the first element if impl_spec* is x86_64-linux, push the macro and return 1
  mov rdi, with_macros_supported_platform_barray
  mov rsi, qword[r13+8]
  call compare_barrays
  cmp rax, 0
  je .not_our_platform

  mov rdi, qword[macro_stack_structural] ; macro stack
  mov rsi, r12                           ; macro name barray
  mov rdx, qword[r13+16]
  call macro_stack_push
  mov rax, 1
  jmp .epilogue

  .not_our_platform:

  mov rax, 0
  .epilogue:
  pop r14
  pop r13
  pop r12
  ret

;;; _with_macros_push_macro(macro_spec*)
;;;   Pushes a macro spec to the macro spec if there's an implementation for a platform
;;;   we support, else pushes a macro with the same name that produces an error.
;;;
;;;   Undefined behavior if macro_spec is not a parray.
_with_macros_push_macro:
  push r12
  push r13
  push r14
  push r15
  sub rsp, 8

  mov r12, rdi ; r12 = macro spec

  ;; If our input parray has fewer than 2 elements, error
  mov rdi, qword[r12]
  not rdi
  cmp rdi, 2
  jge .enough_elements

  mov rdi, with_macros_spec_too_short_error
  mov rsi, with_macros_spec_too_short_error_len
  call error_exit

  .enough_elements:

  ;; If this macro spec's first element isn't a barray for the name of a macro,
  ;; error and exit
  mov rdi, qword[r12+8]
  cmp qword[rdi], 0
  jge .name_is_barray

  mov rdi, with_macros_name_not_barray_error
  mov rsi, with_macros_name_not_barray_error_len
  call error_exit

  .name_is_barray:

  ;; Iterate over implementations
  mov r14, r12
  add r14, 16  ; r14 = pointer to pointer to first implementation

  mov r15, qword[r12]
  not r15
  dec r15 ; r15 = counter

  .impl_loop:
  cmp r15, 0
  je .impl_loop_break

  ;; If this implementation spec isn't a parray, error and exit
  mov rdi, qword[r14]
  mov rsi, qword[rdi]
  cmp rsi, 0
  jl .impl_is_parray

  mov rdi, with_macros_impl_spec_not_parray_error
  mov rsi, with_macros_impl_spec_not_parray_error_len
  call error_exit

  .impl_is_parray:

  ;; Push the implementation if we support the platform. Break loop if we succeed.
  mov rdi, qword[r12+8] ; macro name
  mov rsi, qword[r14]
  call _with_macros_try_push_impl

  ;; Return 1 if we succeeded in the push.
  cmp rax, 1
  je .epilogue

  add r14, 8
  dec r15
  jmp .impl_loop

  .impl_loop_break:

  ;; We failed to push an implementation, push our error-producing macro in it's place so
  ;; any attempt to use this macro fails with an error.

  mov rdi, qword[macro_stack_structural]  ; macro stack
  mov rsi, qword[r12+8]                   ; macro name
  mov rdx, with_macros_unsupported_platform                     ; code
  mov rcx, (with_macros_unsupported_platform_end - with_macros_unsupported_platform)  ; length
  call macro_stack_push_range

  .epilogue:
  add rsp, 8
  pop r15
  pop r14
  pop r13
  pop r12
  ret

;;; _with_macros_push_macros(macro_list*)
;;;   Returns the quantity of macros pushed
;;;
;;;   Undefined behavior if macro_list is not a parray
_with_macros_push_macros:
  push r12
  push r13
  push r14
  push r15
  sub rsp, 8

  mov r12, rdi ; r12 = macro list (already verified as parray by caller)
  mov r15, 0   ; push counter

  ;; Iterate over macros:
  mov r13, qword[r12]
  not r13               ; r13 = macro count
  mov r14, r12
  add r14, 8            ; r14 = pointer to pointer to first macro

  .macro_loop:
  cmp r13, 0
  je .macro_loop_break

  ;; Error if the macro specifier isn't a parray
  mov rdi, qword[r14]
  cmp qword[rdi], 0
  jl .spec_is_parray

  mov rdi, with_macros_need_parray_2_error
  mov rsi, with_macros_need_parray_2_error_len
  call error_exit

  .spec_is_parray:

  ;; Push the macro with _with_macros_push_macro using macroexpanded macro spec
  ;; (in case it uses macros we just defined)

  call byte_buffer_new
  push rax
  sub rsp, 8

  mov rdi, qword[r14]
  mov rsi, rax
  mov rdx, 2 ; greedy expand
  call structural_macro_expand

  mov rdi, rax
  call _with_macros_push_macro
  inc r15

  add rsp, 8
  pop rdi
  call byte_buffer_free

  add r14, 8 ; r14 = pointer to pointer to next macro
  dec r13
  jmp .macro_loop
  .macro_loop_break:

  ;; Return quantity of macros successfully pushed
  mov rax, r15

  add rsp, 8
  pop r15
  pop r14
  pop r13
  pop r12
  ret

;;; with_macros(structure*, output_byte_buffer*) -> output buf relative ptr
with_macros:
  push r12
  push r13
  push r14
  push r15
  push rbx

  mov r12, rdi ; input structure
  mov r13, rsi ; output bytpe buffer

  ;; If input has less than 3 items, just return -1 and return to expand into nothing,
  mov rax, -1
  mov rdi, qword[r12]
  not rdi
  cmp rdi, 3
  jl .epilogue

  ;; Macroexpand the 2nd item in the input structure (macro list parray)
  mov rax, byte_buffer_new
  call rax
  mov r14, rax ; r14 = byte buffer for 2nd input macroexpansion (macro list)

  mov rdi, qword[r12+16]
  mov rsi, r14
  mov rdx, 1 ; SHY b/c we need to be able to use the macros we define as we go
  mov rax, structural_macro_expand
  call rax
  mov r15, rax ; r15 = 2nd input macroexpansion

  ;; If the 2nd item in the input structure parray isn't a parray, error (this is supposed to me a list of macros)
  cmp qword[r15], 0
  jl .is_parray

  mov rdi, with_macros_need_parray_error
  mov rsi, with_macros_need_parray_error_len
  mov rax, error_exit
  call rax

  .is_parray:

  ;; Iterate over list of macros and push them to macro stack
  mov rdi, r15
  mov rax, _with_macros_push_macros
  call rax

  push rax
  sub rsp, 8

  ;; Free the macroexpanded 2nd item from our input
  mov rdi, r14
  mov rax, byte_buffer_free
  call rax

  ;; Macroexpand 3rd item in the input structure into our output buffer
  mov rdi, qword[r12+24]
  mov rsi, r13
  mov rdx, 2 ; greedy expand
  mov rax, structural_macro_expand
  call rax
  mov rbx, rax ; rbx = abs pointer to result

  mov rdi, r13
  mov rax, byte_buffer_get_buf
  call rax
  sub rbx, rax ; rbx = relative pointer to result

  add rsp, 8
  pop rax ; rax = macro pushed count

  ;; Pop all the macros we pushed
  ;; TODO Just popping the correct number of macros isn't a good approach to this,
  ;;      Our child macros may push but not pop macros to implement some kind of
  ;;      "global" macro setup. We need some way for push_macro to return an id such that
  ;;      we keep track of the ids and pop those specific ids. Would be much less fragile.

  .pop_loop:
  cmp rax, 0
  je .break_pop_loop
  push rax
  sub rsp, 8

  mov rdi, qword[macro_stack_structural] ; macro stack
  mov rax, macro_stack_pop
  call rax

  add rsp, 8
  pop rax
  dec rax
  .break_pop_loop:

  ;; Return buffer relative pointer to our structure in output buffer
  mov rax, rbx
  .epilogue:
  pop rbx
  pop r15
  pop r14
  pop r13
  pop r12
  ret
with_macros_end:

;;; with_macros_unsupported_platform(structure*, output_byte_buffer*) -> output buf relative ptr
;;;   Macro pushed to the stack if a macro in with-macros is defined without an
;;;   implementation for a platform we support.
;;;
;;;   Just produces an error and exits.
with_macros_unsupported_platform:
  mov rdi, with_macros_unsupported_platform_error
  mov rsi, with_macros_unsupported_platform_error_len
  mov rax, error_exit
  call rax

  ret
with_macros_unsupported_platform_end:



