;; TODO: all builtin macros should be prefixed with aarrp/

section .text
global push_builtin_structural_macros

extern byte_buffer_new
extern byte_buffer_free
extern byte_buffer_extend
extern byte_buffer_get_buf
extern byte_buffer_push_byte
extern byte_buffer_push_bytes
extern byte_buffer_push_int64
extern byte_buffer_push_int32
extern byte_buffer_push_int16
extern byte_buffer_read_int64
extern byte_buffer_pop_int64
extern byte_buffer_push_barray
extern byte_buffer_write_int64
extern byte_buffer_get_data_length
extern byte_buffer_push_barray_bytes
extern byte_buffer_push_byte_n_times
extern byte_buffer_push_int_as_width_LE
extern byte_buffer_push_int_as_width_BE

extern structural_macro_expand
extern structural_macro_expand_tail

extern write
extern write_as_base
extern write_char
extern compare_barrays
extern print
extern error_exit
extern parray_tail_new
extern free
extern parse_uint
extern barray_deposit_bytes
extern malloc
extern barray_equalp

extern kv_stack_new
extern kv_stack_pop
extern kv_stack_free
extern kv_stack_push
extern kv_stack_pop_by_id
extern kv_stack_value_by_key
extern kv_stack_bindump_buffers
extern kv_stack_top_value
extern kv_stack_value_by_id

extern macro_stack_structural

extern assert_stack_aligned

section .rodata

barray_test_macro_name: db 11,0,0,0,0,0,0,0,"barray-test"
parray_test_macro_name: db 11,0,0,0,0,0,0,0,"parray-test"
nothing_macro_name: db 7,0,0,0,0,0,0,0,"nothing"
elf64_relocatable_macro_name: db 17,0,0,0,0,0,0,0,"elf64-relocatable"
barray_cat_macro_name: db 16,0,0,0,0,0,0,0,"aarrp/barray-cat"
with_macros_macro_name: db 17,0,0,0,0,0,0,0,"aarrp/with-macros"
with_macro_name: db 10,0,0,0,0,0,0,0,"aarrp/with"
builtin_bb_push_int64_macro_name: db 46,0,0,0,0,0,0,0,"aarrp/builtin-func-addr/byte-buffer-push-int64"
builtin_bb_push_int32_macro_name: db 46,0,0,0,0,0,0,0,"aarrp/builtin-func-addr/byte-buffer-push-int32"
builtin_bb_push_int16_macro_name: db 46,0,0,0,0,0,0,0,"aarrp/builtin-func-addr/byte-buffer-push-int16"
builtin_bb_push_int8_macro_name: db 45,0,0,0,0,0,0,0,"aarrp/builtin-func-addr/byte-buffer-push-int8"
builtin_bb_push_barray_macro_name: db 47,0,0,0,0,0,0,0,"aarrp/builtin-func-addr/byte-buffer-push-barray"
builtin_barray_equalp_macro_name: db 37,0,0,0,0,0,0,0,"aarrp/builtin-func-addr/barray-equalp"

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

;;; Stuff for barray-cat macro:
barray_cat_abs_ref_name: db 13,0,0,0,0,0,0,0,"label-abs-ref"
barray_cat_rel_ref_name: db 13,0,0,0,0,0,0,0,"label-rel-ref"
barray_cat_label_name: db 5,0,0,0,0,0,0,0,"label"
barray_cat_label_scope_name: db 11,0,0,0,0,0,0,0,"label-scope"
barray_cat_global_label_name: db 12,0,0,0,0,0,0,0,"global-label"
barray_cat_be_name: db 2,0,0,0,0,0,0,0,"BE"


barray_cat_element_error: db "ERROR: Invalid element in aarrp/barray-cat. Must be one of: raw barray, label, global-label, label-scope, label-abs-ref, label-rel-ref",10
barray_cat_element_error_len:  equ $ - barray_cat_element_error

barray_cat_no_label_error: db "ERROR: Unable to find referenced label in aarrp/barray-cat",10
barray_cat_no_label_error_len:  equ $ - barray_cat_no_label_error

;;; Stuff for with macro:
with_definitions_not_list_error: db "ERROR: Definitions list in aarrp/with is not a parray. Should be a parray. Try (aarrp/with ((my-thing foo) (my-other-thing foo)) my-shit)",10
with_definitions_not_list_error_len:  equ $ - with_definitions_not_list_error

with_definition_not_2_error: db "ERROR: A definition in aarrp/with isn't a parray of length 2. It must be.",10
with_definition_not_2_error_len:  equ $ - with_definition_not_2_error

with_definition_not_barray_error: db "ERROR: A definition in aarrp/with doesn't start with a barray (as the name). It must.",10
with_definition_not_barray_error_len:  equ $ - with_definition_not_barray_error


with_rawref_not_barray_error: db "ERROR: Accessor using barray-raw-addr references value that's not a barray. barray-raw-addr only works with barray values.",10
with_rawref_not_barray_error_len:  equ $ - with_rawref_not_barray_error

with_access_bad_form_error: db "ERROR: Accessor macro call (from aarrp/with) has invalid form.",10
with_access_bad_form_error_len:  equ $ - with_access_bad_form_error


with_be_name: db 2,0,0,0,0,0,0,0,"BE"
with_addr_name: db 4,0,0,0,0,0,0,0,"addr"
with_baddr_name: db 15,0,0,0,0,0,0,0,"barray-raw-addr"

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
  sub rsp, 16
  mov qword[rsp], 8
  mov qword[rsp+8], barray_test
  mov rdi, qword[macro_stack_structural]   ; macro stack
  mov rsi, barray_test_macro_name          ; macro name
  mov rdx, rsp                             ; code
  call kv_stack_push
  add rsp, 16

  ;; Push builtin_bb_push_int64 macro
  sub rsp, 16
  mov qword[rsp], 8
  mov qword[rsp+8], builtin_bb_push_int64
  mov rdi, qword[macro_stack_structural]    ; macro stack
  mov rsi, builtin_bb_push_int64_macro_name ; macro name
  mov rdx, rsp                              ; code
  call kv_stack_push
  add rsp, 16

  ;; Push builtin_bb_push_int32 macro
  sub rsp, 16
  mov qword[rsp], 8
  mov qword[rsp+8], builtin_bb_push_int32
  mov rdi, qword[macro_stack_structural]    ; macro stack
  mov rsi, builtin_bb_push_int32_macro_name ; macro name
  mov rdx, rsp                              ; code
  call kv_stack_push
  add rsp, 16

  ;; Push builtin_bb_push_int16 macro
  sub rsp, 16
  mov qword[rsp], 8
  mov qword[rsp+8], builtin_bb_push_int16
  mov rdi, qword[macro_stack_structural]    ; macro stack
  mov rsi, builtin_bb_push_int16_macro_name ; macro name
  mov rdx, rsp                              ; code
  call kv_stack_push
  add rsp, 16

  ;; Push builtin_barray_equalp macro
  sub rsp, 16
  mov qword[rsp], 8
  mov qword[rsp+8], builtin_barray_equalp
  mov rdi, qword[macro_stack_structural]    ; macro stack
  mov rsi, builtin_barray_equalp_macro_name ; macro name
  mov rdx, rsp                              ; code
  call kv_stack_push
  add rsp, 16

  ;; Push builtin_bb_push_int8 macro
  sub rsp, 16
  mov qword[rsp], 8
  mov qword[rsp+8], builtin_bb_push_int8
  mov rdi, qword[macro_stack_structural]    ; macro stack
  mov rsi, builtin_bb_push_int8_macro_name ; macro name
  mov rdx, rsp                              ; code
  call kv_stack_push
  add rsp, 16

  ;; Push builtin_bb_push_barray macro
  sub rsp, 16
  mov qword[rsp], 8
  mov qword[rsp+8], builtin_bb_push_barray
  mov rdi, qword[macro_stack_structural]     ; macro stack
  mov rsi, builtin_bb_push_barray_macro_name ; macro name
  mov rdx, rsp                               ; code
  call kv_stack_push
  add rsp, 16

  ;; Push parray-test macro
  sub rsp, 16
  mov qword[rsp], 8
  mov qword[rsp+8], parray_test
  mov rdi, qword[macro_stack_structural]   ; macro stack
  mov rsi, parray_test_macro_name          ; macro name
  mov rdx, rsp                             ; code
  call kv_stack_push
  add rsp, 16

  ;; Push nothing macro
  sub rsp, 16
  mov qword[rsp], 8
  mov qword[rsp+8], nothing
  mov rdi, qword[macro_stack_structural]   ; macro stack
  mov rsi, nothing_macro_name          ; macro name
  mov rdx, rsp                     ; code
  call kv_stack_push
  add rsp, 16

  ;; Push elf64_relocatable macro
  sub rsp, 16
  mov qword[rsp], 8
  mov qword[rsp+8], elf64_relocatable
  mov rdi, qword[macro_stack_structural]   ; macro stack
  mov rsi, elf64_relocatable_macro_name          ; macro name
  mov rdx, rsp                             ; code
  call kv_stack_push
  add rsp, 16

  ;; Push barray-cat macro
  sub rsp, 16
  mov qword[rsp], 8
  mov qword[rsp+8], barray_cat
  mov rdi, qword[macro_stack_structural]  ; macro stack
  mov rsi, barray_cat_macro_name          ; macro name
  mov rdx, rsp                            ; code
  call kv_stack_push
  add rsp, 16

  ;; Push with-macros macro
  sub rsp, 16
  mov qword[rsp], 8
  mov qword[rsp+8], with_macros
  mov rdi, qword[macro_stack_structural]  ; macro stack
  mov rsi, with_macros_macro_name          ; macro name
  mov rdx, rsp                    ; code
  call kv_stack_push
  add rsp, 16

  ;; Push with macro
  sub rsp, 16
  mov qword[rsp], 8
  mov qword[rsp+8], with_
  mov rdi, qword[macro_stack_structural]  ; macro stack
  mov rsi, with_macro_name          ; macro name
  mov rdx, rsp                    ; code
  call kv_stack_push
  add rsp, 16

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

  ;; TODO doc
builtin_bb_push_int64:
  push r12
  mov r12, rsi

  mov rdi, r12
  mov rsi, 8
  mov rax, byte_buffer_push_int64
  call rax

  mov rdi, r12
  mov rsi, byte_buffer_push_int64
  mov rax, byte_buffer_push_int64
  call rax
  mov rax, 0

  pop r12
  ret
builtin_bb_push_int64_end:

builtin_bb_push_int32:
  push r12
  mov r12, rsi

  mov rdi, r12
  mov rsi, 8
  mov rax, byte_buffer_push_int64
  call rax

  mov rdi, r12
  mov rsi, byte_buffer_push_int32
  mov rax, byte_buffer_push_int64
  call rax
  mov rax, 0

  pop r12
  ret
builtin_bb_push_int32_end:


builtin_bb_push_int16:
  push r12
  mov r12, rsi

  mov rdi, r12
  mov rsi, 8
  mov rax, byte_buffer_push_int64
  call rax

  mov rdi, r12
  mov rsi, byte_buffer_push_int16
  mov rax, byte_buffer_push_int64
  call rax
  mov rax, 0

  pop r12
  ret
builtin_bb_push_int16_end:

builtin_barray_equalp:
  push r12
  mov r12, rsi

  mov rdi, r12
  mov rsi, 8
  mov rax, byte_buffer_push_int64
  call rax

  mov rdi, r12
  mov rsi, barray_equalp
  mov rax, byte_buffer_push_int64
  call rax
  mov rax, 0

  pop r12
  ret
builtin_barray_equalp_end:

builtin_bb_push_int8:
  push r12
  mov r12, rsi

  mov rdi, r12
  mov rsi, 8
  mov rax, byte_buffer_push_int64
  call rax

  mov rdi, r12
  mov rsi, byte_buffer_push_byte
  mov rax, byte_buffer_push_int64
  call rax
  mov rax, 0

  pop r12
  ret
builtin_bb_push_int8_end:

  ;; TODO doc
builtin_bb_push_barray:
  push r12
  mov r12, rsi

  mov rdi, r12
  mov rsi, 8
  mov rax, byte_buffer_push_int64
  call rax

  mov rdi, r12
  mov rsi, byte_buffer_push_barray
  mov rax, byte_buffer_push_int64
  call rax
  mov rax, 0

  pop r12
  ret
builtin_bb_push_barray_end:

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

;;; _barray_cat_push_layer(parray*, label_stack*, output_byte_buffer*)
;;;   * pushes all labels in this layer
;;;   * pushes all content in this layer (recursively)
_barray_cat_push_layer:
  push r12
  push r13
  push r14
  push r15
  push rbx

  mov r12, rdi ; r12 = layer parray*
  mov r13, rsi ; r13 = label stack*
  mov r14, rdx ; r14 = output byte buffer*

  ;; Get current counter
  mov rdi, r14
  call byte_buffer_get_data_length
  sub rax, 8 ; subtract barray len int

  ;; Push labels
  mov rdi, r12
  mov rsi, r13
  mov rdx, rax
  mov rcx, 1
  call _barray_cat_push_layer_labels
  mov r15, rax ; r15 = label count

  ;; Push content (push_content should call us to dig into the tree)
  mov rdi, r12
  mov rsi, r14
  mov rdx, r13
  call _barray_cat_push_layer_content

  ;; Pop labels
  .poploop:
  cmp r15, 0
  je .poploop_break

  mov rdi, r13
  call kv_stack_pop

  dec r15
  jmp .poploop
  .poploop_break:

  pop rbx
  pop r15
  pop r14
  pop r13
  pop r12
  ret

;;; _barray_cat_push_layer_labels(parray*,
;;;                               label_stack*,
;;;                               offset,
;;;                               push_locals) -> push count, byte counter
;;;   Scans the input parray and pushes all top-level labels at the correct address
;;;   to the label stack.
;;;
;;;   Offset specifies the starting point for label addresses, as we might not be at the root.
;;;
;;;   If push_locals is 1, we will push locals at our top level
;;;   Non-top-level locals will never be pushed.
;;;
;;;   Returns the quantity of labels pushed
_barray_cat_push_layer_labels:
  push rbp
  mov rbp, rsp
  push r12
  push r13
  push r14
  push r15
  push rbx
  sub rsp, 24

  mov r12, rdi ; r12 = layer parray*
  mov r13, rsi ; r13 = label stack*
  mov r14, rdx ; r14 = counter
  mov r15, rcx ; r15 = push_locals bool

  mov qword[rbp-56], 0 ; push counter

  ;; Iterate over each element in layer
  mov rbx, qword[r12]
  not rbx
  add r12, 8 ; move past length
  .element_loop:
  cmp rbx, 0
  je .element_loop_break

  ;; qword[rbp-48] = pointer to this element
  mov rax, qword[r12]
  mov qword[rbp-48], rax

  ;; If it's a barray, add the length of the barray to our counter. Continue.
  mov rax, qword[rbp-48]
  cmp qword[rax], 0
  jl .not_barray
  add r14, qword[rax]
  jmp .element_loop_continue
  .not_barray:

  ;; If it's a label reference, add the size of the label reference to our counter. Continue.
  mov rax, qword[rbp-48]
  cmp qword[rax], 0
  jge .not_label_ref
    ; Check if it has 4 elements, otherwise not a (valid) label ref
    mov rdi, qword[rax]
    not rdi
    cmp rdi, 4
    jne .not_label_ref

    ; Check if the 3rd element is a barray
    mov rax, qword[rbp-48]
    mov rdi, qword[rax+24] ; rdi = pointer to 3rd barray
    cmp qword[rdi], 0
    jl .not_label_ref

    ; Check if it's label-abs-ref or label-rel-ref
    mov rax, qword[rbp-48]
    mov rdi, qword[rax+8]
    mov rsi, barray_cat_rel_ref_name
    call compare_barrays
    cmp rax, 1
    je .is_label_ref

    mov rax, qword[rbp-48]
    mov rdi, qword[rax+8]
    mov rsi, barray_cat_abs_ref_name
    call compare_barrays
    cmp rax, 1
    je .is_label_ref

    jmp .not_label_ref
    .is_label_ref:

    ; Parse the integer (TODO parse integer function should error for us if it's not a valid int)
    mov rax, qword[rbp-48]
    mov rdi, qword[rax+24] ; rdi = pointer to 3rd barray
    mov rsi, 10            ; base 10
    call parse_uint

    ; Add the integer to our counter
    add r14, rax
    jmp .element_loop_continue
  .not_label_ref:

  ;; TODO Maybe if it's label-offset, apply that offset to our counter?

  ;; If it's a global label, push it's name with our current counter value. Continue.
  mov rax, qword[rbp-48]
  cmp qword[rax], 0
  jge .not_global_label
    ; Check if it has 2 elements
    mov rdi, qword[rax]
    not rdi
    cmp rdi, 2
    jne .not_global_label

    ; Check if the second element is a barray
    mov rax, qword[rbp-48]
    mov rdi, qword[rax+16]
    cmp qword[rdi], 0
    jl .not_global_label

    ; Check if the first element is global-label
    mov rax, qword[rbp-48]
    mov rdi, qword[rax+8]
    mov rsi, barray_cat_global_label_name
    call compare_barrays
    cmp rax, 1
    jne .not_global_label

    ; Push the 2nd element as our label name w/ our current counter as the value
    mov rax, qword[rbp-48] ; rax = pointer to global-label parray
    mov rsi, qword[rax+16] ; rsi = pointer to 2nd element

    sub rsp, 16 ; allocate 16 bytes on the stack
    mov qword[rsp], 8 ; barray length is 1
    mov qword[rsp+8], r14 ; value is our counter
    mov rdi, r13 ; the label stack
    mov rdx, rsp
    call kv_stack_push
    add rsp, 16 ; free our 16 byte stack allocation
    inc qword[rbp-56]

    jmp .element_loop_continue
  .not_global_label:

  ;; If it's a local label AND push_locals is 1, push it's name with our counter. Continue.
  mov rax, qword[rbp-48]
  cmp qword[rax], 0
  jge .not_local_label
    ; Check if it has 2 elements
    mov rdi, qword[rax]
    not rdi
    cmp rdi, 2
    jne .not_local_label

    ; Check if the second element is a barray
    mov rax, qword[rbp-48]
    mov rdi, qword[rax+16]
    cmp qword[rdi], 0
    jl .not_local_label

    ; Check if the first element is label
    mov rax, qword[rbp-48]
    mov rdi, qword[rax+8]
    mov rsi, barray_cat_label_name
    call compare_barrays
    cmp rax, 1
    jne .not_local_label

    ; If local pushes are disabled, don't push
    cmp r15, 0
    je .nopush

    ; Push the 2nd element as our label name w/ our current counter as the value
    mov rax, qword[rbp-48] ; rax = pointer to global-label parray
    mov rsi, qword[rax+16] ; rsi = pointer to 2nd element

    sub rsp, 16 ; allocate 16 bytes on the stack
    mov qword[rsp], 8 ; barray length is 8
    mov qword[rsp+8], r14 ; value is our counter
    mov rdi, r13 ; the label stack
    mov rdx, rsp
    call kv_stack_push
    add rsp, 16 ; free our 16 byte stack allocation
    inc qword[rbp-56]
    .nopush:

    jmp .element_loop_continue
  .not_local_label:

  ;; If it's a label scope, recurse then continue
  mov rax, qword[rbp-48]
  cmp qword[rax], 0
  jge .not_label_scope
    ; Check if it has at least 1 element
    mov rdi, qword[rax]
    not rdi
    cmp rdi, 1
    jl .not_label_scope

    ; Check if the first element is label-scope
    mov rax, qword[rbp-48]
    mov rdi, qword[rax+8]
    mov rsi, barray_cat_label_scope_name
    call compare_barrays
    cmp rax, 1
    jne .not_label_scope

    ; If it has exactly one element, take no action
    mov rax, qword[rbp-48]
    mov rdi, qword[rax]
    not rdi
    cmp rdi, 1
    je .label_scope_noaction

    ; Compute the tail of the scope (remove first element)
    mov rdi, qword[rbp-48]
    call parray_tail_new
    push rax
    sub rsp, 8 ; align stack

    ; Call self with push_locals as 0
    mov rdi, rax ; the parray tail*
    mov rsi, r13 ; label stack*
    mov rdx, r14 ; counter
    mov rcx, 0   ; don't push locals for child
    call _barray_cat_push_layer_labels

    ; Assign it's 2nd return value (byte counter) to our counter
    mov r14, rdx

    ; Free the parray tail
    add rsp, 8
    pop rdi
    call free

    .label_scope_noaction:
    jmp .element_loop_continue
  .not_label_scope:

  ;; If we get here, error
  mov rdi, barray_cat_element_error
  mov rsi, barray_cat_element_error_len
  call error_exit

  .element_loop_continue:
  add r12, 8 ; next element
  dec rbx
  jmp .element_loop
  .element_loop_break:

  mov rax, qword[rbp-56] ; Return push count
  mov rdx, r14           ; Return counter as second value

  add rsp, 24
  pop rbx
  pop r15
  pop r14
  pop r13
  pop r12
  pop rbp
  ret

;;; _barray_cat_push_layer_content(parray*, output_byte_buffer*, label_stack*)
;;;   Scans the input parray and:
;;;     *  pushes all raw barrays to the output
;;;     *  pushes all sub-layers
;;;     *  resolves all label refs, pushing them to the output
_barray_cat_push_layer_content:
  push rbp
  mov rbp, rsp
  push r12
  push r13
  push r14
  push r15
  push rbx
  sub rsp, 24

  mov r12, rdi ; layer parray*
  mov r13, rsi ; output byte buffer*
  mov rbx, rdx ; label stack*

  mov r14, qword[rdi]
  not r14
  add r12, 8 ; move past length
  .element_loop:
  cmp r14, 0
  jle .element_loop_break

  ;; r15 = pointer to this element
  mov r15, qword[r12]

  ;; If this element is a raw barray, push it to the output. Continue.
  cmp qword[r15], 0
  jl .not_barray
  mov rdi, r13
  mov rsi, r15
  call byte_buffer_push_barray_bytes
  jmp .element_loop_continue
  .not_barray:

  ;; If this element - now known to be a parray - is empty, then continue.
  cmp qword[r15], -1
  je .element_loop_continue

  ;; If this element is a label or global-label, ignore it. Continue.
  mov rdi, qword[r15+8]
  mov rsi, barray_cat_global_label_name
  call compare_barrays
  cmp rax, 1
  je .element_loop_continue

  mov rdi, qword[r15+8]
  mov rsi, barray_cat_label_name
  call compare_barrays
  cmp rax, 1
  je .element_loop_continue

  ;; If this element is a label scope, recurse through _barray_cat_push_layer. Continue.
  mov rdi, qword[r15+8]
  mov rsi, barray_cat_label_scope_name
  call compare_barrays
  cmp rax, 1
  jne .not_label_scope

  mov rdi, r15
  call parray_tail_new
  push rax
  sub rsp, 8

  mov rdi, rax
  mov rsi, rbx
  mov rdx, r13
  call _barray_cat_push_layer

  add rsp, 8
  pop rax

  mov rdi, rax
  call free

  jmp .element_loop_continue
  .not_label_scope:

  ;; If this element is a ref, resolve and output the ref. Continue.

  mov qword[rbp-48], 0 ; 0 = abs

  mov rdi, qword[r15+8]
  mov rsi, barray_cat_abs_ref_name
  call compare_barrays
  cmp rax, 1
  je .is_ref

  mov rdi, qword[r15+8]
  mov rsi, barray_cat_rel_ref_name
  call compare_barrays
  cmp rax, 1
  je .is_ref_and_rel

  jmp .not_ref
  .is_ref_and_rel:

  mov rdi, r13
  call byte_buffer_get_data_length
  sub rax, 8

  sub qword[rbp-48], rax ; = -current-pos

  mov rdi, qword[r15+24]
  mov rsi, 10
  call parse_uint
  sub qword[rbp-48], rax

  .is_ref:

  mov rdi, qword[r15+32]
  mov rsi, barray_cat_be_name
  call compare_barrays
  cmp rax, 1
  mov rdi, byte_buffer_push_int_as_width_LE
  mov rsi, byte_buffer_push_int_as_width_BE
  cmove rdi, rsi
  mov qword[rbp-56], rdi

  mov rdi, rbx
  mov rsi, qword[r15+16]
  call kv_stack_value_by_key
  push rax
  sub rsp, 8

  ;; Error if rax is NULL/0
  cmp rax, 0
  jne .found_label

  mov rdi, barray_cat_no_label_error
  mov rsi, barray_cat_no_label_error_len
  call error_exit

  .found_label:

  mov rdi, qword[r15+24]
  mov rsi, 10
  call parse_uint

  add rsp, 8
  pop rdx

  mov rsi, qword[rbp-48]
  add rsi, qword[rdx+8]

  mov rdx, rax
  mov rdi, r13
  call qword[rbp-56]

  jmp .element_loop_continue
  .not_ref:

  ;; Error if we get here
  mov rdi, barray_cat_element_error
  mov rsi, barray_cat_element_error_len
  call error_exit

  .element_loop_continue:
  add r12, 8 ; next element
  dec r14
  jmp .element_loop
  .element_loop_break:

  add rsp, 24
  pop rbx
  pop r15
  pop r14
  pop r13
  pop r12
  pop rbp
  ret

;;; barray_cat(structure*, output_byte_buffer*) -> output buf relative ptr
barray_cat:
  push rbp
  mov rbp, rsp
  push r12
  push r13
  push r14
  push r15
  push rbx
  sub rsp, 24

  mov r12, rdi ; input structure
  mov r13, rsi ; output byte buffer

  ;; Macroexpand tail of our input
  mov rax, byte_buffer_new
  call rax
  mov qword[rbp-48], rax ; qword[rbp-48] = macroexpansion backing buffer

  mov rdi, r12
  mov rsi, qword[rbp-48]
  mov rdx, 2 ; greedy expand
  mov rax, structural_macro_expand_tail
  call rax
  mov r12, rax ; r12 = macroexpanded tail of input structure

  ;; Push a length placeholder
  mov rdi, r13
  mov rsi, 0
  mov rax, byte_buffer_push_int64
  call rax

  ;; Create label stack
  mov rax, kv_stack_new
  call rax
  mov qword[rbp-56], rax ; qword[rbp-56] = label stack

  ;; Push the layer
  mov rdi, r12
  mov rsi, qword[rbp-56]
  mov rdx, r13
  mov rax, _barray_cat_push_layer
  call rax

  ;; Free label stack
  mov rdi, qword[rbp-56]
  mov rax, kv_stack_free
  call rax

  ;; Update output length
  mov rdi, r13
  mov rax, byte_buffer_get_data_length
  call rax
  sub rax, 8

  mov rdi, r13
  mov rsi, 0
  mov rdx, rax
  mov rax, byte_buffer_write_int64
  call rax

  ;; Free our macroexpansion
  mov rdi, qword[rbp-48]
  mov rax, byte_buffer_free
  call rax

  mov rax, 0
  add rsp, 24
  pop rbx
  pop r15
  pop r14
  pop r13
  pop r12
  pop rbp
  ret
barray_cat_end:

;;; _with_macros_try_push_impl(macro_name_barray*, impl_spec*)
;;;   Attempts to push a macro implementation spec to the structural macro stack
;;;
;;;   Undefined behavior if impl_spec* isn't a parray.
;;;   Undefined behavior if macro_name_barray* isn't a barray.
;;;
;;;   Returns macro id on success, -1 on failure.
_with_macros_try_push_impl:
  push r12
  push r13
  push r14
  push r15
  push rbx

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

  ;; If the first element if impl_spec* is x86_64-linux, push the macro and return id
  mov rdi, with_macros_supported_platform_barray
  mov rsi, qword[r13+8]
  call compare_barrays
  cmp rax, 0
  je .not_our_platform

  ; malloc enough space to store our code
  mov rdx, qword[r13+16]
  mov rdi, qword[rdx]
  call malloc
  mov r15, rax ; r15 = our space for code

  ; Copy our barray into that space
  mov rdi, qword[r13+16]
  mov rsi, r15
  call barray_deposit_bytes

  ; push the macro
  sub rsp, 16
  mov qword[rsp], 8
  mov qword[rsp+8], r15
  mov rdi, qword[macro_stack_structural] ; macro stack
  mov rsi, r12                           ; macro name barray
  mov rdx, rsp
  call kv_stack_push
  add rsp, 16
  jmp .epilogue

  .not_our_platform:

  mov rax, -1
  .epilogue:
  pop rbx
  pop r15
  pop r14
  pop r13
  pop r12
  ret

;;; _with_macros_push_macro(macro_spec*)
;;;   Pushes a macro spec to the macro spec if there's an implementation for a platform
;;;   we support, else pushes a macro with the same name that produces an error.
;;;
;;;   Undefined behavior if macro_spec is not a parray.
;;;
;;;   Returns macro id
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

  ;; Return macro id if we succeeded in the push.
  cmp rax, -1
  jne .epilogue

  add r14, 8
  dec r15
  jmp .impl_loop

  .impl_loop_break:

  ;; We failed to push an implementation, push our error-producing macro in it's place so
  ;; any attempt to use this macro fails with an error.

  sub rsp, 16
  mov qword[rsp], 8
  mov qword[rsp+8], with_macros_unsupported_platform
  mov rdi, qword[macro_stack_structural]  ; macro stack
  mov rsi, qword[r12+8]                   ; macro name
  mov rdx, rsp                     ; code
  call kv_stack_push
  add rsp, 16
  ;; return id

  .epilogue:
  add rsp, 8
  pop r15
  pop r14
  pop r13
  pop r12
  ret

;;; _with_macros_push_macros(macro_list*, id_byte_buffer*)
;;;   Undefined behavior if macro_list is not a parray
_with_macros_push_macros:
  push r12
  push r13
  push r14
  push r15
  push rbx

  mov r12, rdi ; r12 = macro list (already verified as parray by caller)
  mov rbx, rsi ; rbx = id byte buffer

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

  ;; Push id to our id list
  mov rdi, rbx
  mov rsi, rax
  call byte_buffer_push_int64

  add rsp, 8
  pop rdi
  call byte_buffer_free

  add r14, 8 ; r14 = pointer to pointer to next macro
  dec r13
  jmp .macro_loop
  .macro_loop_break:

  pop rbx
  pop r15
  pop r14
  pop r13
  pop r12
  ret

;;; with_macros(structure*, output_byte_buffer*) -> output buf relative ptr
with_macros:
  push rbp
  mov rbp, rsp
  push r12
  push r13
  push r14
  push r15
  push rbx
  sub rsp, 8 ; alloc for id byte buffer

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

  ;; Allocate byte buffer to track macro ids that we push
  mov rax, byte_buffer_new
  call rax
  mov qword[rbp-48], rax

  ;; Iterate over list of macros and push them to macro stack
  mov rdi, r15
  mov rsi, rax
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

  ;; Pop all the macros we pushed by id
  ;; We do this right-to-left because it's faster for the stack implementation
  mov rdi, qword[rbp-48]
  mov rax, byte_buffer_get_data_length
  call rax

  .pop_loop:
  cmp rax, 0
  jle .pop_loop_break

  push rax
  sub rsp, 8

  mov rdi, qword[rbp-48]
  mov rsi, rax
  sub rsi, 8
  mov rax, byte_buffer_read_int64
  call rax

  mov rdi, qword[macro_stack_structural] ; macro stack
  mov rsi, rax
  mov rax, kv_stack_pop_by_id
  call rax

  ; free the macro - we malloc'd it
  mov rdi, rax
  call free

  add rsp, 8
  pop rax

  sub rax, 8
  jmp .pop_loop
  .pop_loop_break:

  ;; Free id byte buffer
  mov rdi, qword[rbp-48]
  mov rax, byte_buffer_free
  call rax

  ;; Return buffer relative pointer to our structure in output buffer
  mov rax, rbx
  .epilogue:
  add rsp, 8
  pop rbx
  pop r15
  pop r14
  pop r13
  pop r12
  pop rbp
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


_with_template_macro:
  push r12
  push r13
  push r14
  push r15
  push rbx

  mov r12, rdi ; input structure
  mov r13, rsi ; output byte buffer

  mov r14, qword[rel _with_template_macro_end] ; A pointer to our data has been written right after
                                               ; this function in the heap.

  ;; If our input parray has just 1 element, just expand into the value structure directly.
  cmp qword[r12], -2
  jne .not_one_el

  mov rdi, r14
  mov rsi, r13
  mov rdx, 0 ; copy mode
  mov rax, structural_macro_expand
  call rax
  mov rbx, rax ; rbx = absolute pointer to our expansion

  mov rdi, r13
  mov rax, byte_buffer_get_buf
  call rax
  sub rbx, rax ; rbx = relative pointer to our expansion

  mov rax, rbx
  jmp .epilogue
  .not_one_el:

  ;; If our input parray has 4 elements and the second is a barray of value 'addr',
  ;; expand into an address as described by the next two elements
  cmp qword[r12], -5
  jne .not_addr

  mov rdi, qword[r12+16]
  mov rsi, with_addr_name
  mov rax, compare_barrays
  call rax
  cmp rax, 1
  jne .not_addr

  ;; Parse our width int
  mov rdi, qword[r12+24]
  mov rsi, 10
  mov rax, parse_uint
  call rax
  mov rbx, rax ; rbx = width int

  ;; Write barray length (our width)
  mov rdi, r13
  mov rsi, rbx
  mov rax, byte_buffer_push_int64
  call rax

  mov rdi, qword[r12+32]
  mov rsi, with_be_name
  mov rax, compare_barrays
  call rax
  cmp rax, 1
  je .is_BE

  .is_LE:

  mov rdi, r13
  mov rsi, r14
  mov rdx, rbx
  mov rax, byte_buffer_push_int_as_width_LE
  call rax

  mov rax, 0
  jmp .epilogue

  .is_BE:
  mov rdi, r13
  mov rsi, r14
  mov rdx, rbx
  mov rax, byte_buffer_push_int_as_width_BE
  call rax

  mov rax, 0
  jmp .epilogue

  .not_addr:

  ;; If our input parray has 4 elements and the second is a barray of value 'barray-raw-addr',
  ;;      expand into a pointer to the raw bytes of our value. If our value is not a barray, error.
  cmp qword[r12], -5
  jne .not_baddr

  mov rdi, qword[r12+16]
  mov rsi, with_baddr_name
  mov rax, compare_barrays
  call rax
  cmp rax, 1
  jne .not_baddr

  ;; Error if the value isn't a barray
  cmp qword[r14], 0
  jge .val_is_barray

  mov rdi, with_rawref_not_barray_error
  mov rsi, with_rawref_not_barray_error_len
  mov rax, error_exit
  call rax

  .val_is_barray:

  ;; Parse our width int
  mov rdi, qword[r12+24]
  mov rsi, 10
  mov rax, parse_uint
  call rax
  mov rbx, rax ; rbx = width int

  ;; Write barray length (our width)
  mov rdi, r13
  mov rsi, rbx
  mov rax, byte_buffer_push_int64
  call rax

  mov rdi, qword[r12+32]
  mov rsi, with_be_name
  mov rax, compare_barrays
  call rax
  cmp rax, 1
  je .is_BE2

  .is_LE2:

  mov rdi, r13
  mov rsi, r14
  add rsi, 8
  mov rdx, rbx
  mov rax, byte_buffer_push_int_as_width_LE
  call rax

  mov rax, 0
  jmp .epilogue

  .is_BE2:
  mov rdi, r13
  mov rsi, r14
  add rsi, 8
  mov rdx, rbx
  mov rax, byte_buffer_push_int_as_width_BE
  call rax

  mov rax, 0
  jmp .epilogue

  .not_baddr

  ;; Error if we got here, we found no valid accessor forms
  mov rdi, with_access_bad_form_error
  mov rsi, with_access_bad_form_error_len
  mov rax, error_exit
  call rax

  mov rax, -1
  .epilogue:
  pop rbx
  pop r15
  pop r14
  pop r13
  pop r12
  ret
_with_template_macro_end:


;;; _with_push_macro(def-parray*, id_byte_buffer*, data_byte_buffer*)
_with_push_macro:
  push rbp
  mov rbp, rsp
  push r12
  push r13
  push r14
  push r15
  push rbx
  sub rsp, 24

  mov r12, rdi ; definition parray
  mov r13, rsi ; id byte buffer
  mov r14, rdx ; data byte buffer

  ;; Error if the definition is not a parray of 2 elements
  cmp qword[r12], -3
  je .correct_input_size

  mov rdi, with_definition_not_2_error
  mov rsi, with_definition_not_2_error_len
  call error_exit

  .correct_input_size:

  ;; Error if the first element is not a barray
  mov rax, qword[r12+8]
  cmp qword[rax], 0
  jge .first_is_barray

  mov rdi, with_definition_not_barray_error
  mov rsi, with_definition_not_barray_error_len
  call error_exit

  .first_is_barray:

  ;; Init byte buffer to store our data
  ;;
  ;; We do this in our own buffer because we need to point absolute pointers here and
  ;; putting everything directly in the data byte buffer - which grows and reallocs -
  ;; would invalidate those pointers
  mov rax, byte_buffer_new
  call rax
  mov rbx, rax ; rbx = our data byte buffer

  ;; Copy this definition's data to our new byte buffer using macroexpand in cp mode
  mov rdi, qword[r12+16]
  mov rsi, rax
  mov rdx, 0 ; cp
  call structural_macro_expand
  mov qword[rbp-56], rax

  ;; Push a pointer to our byte buffer to the data byte buffer
  mov rdi, r14
  mov rsi, rbx
  mov rax, byte_buffer_push_int64
  call rax

  ;; Malloc space for template macro
  mov rdi, (_with_template_macro_end - _with_template_macro)
  add rdi, 8 ; for our data pointer at the end
  call malloc
  mov qword[rbp-48], rax ; qword[rbp-48] = template macro codespace

  ;; Write our template macro to the allocation
  mov rax, _with_template_macro ; rax = source ptr
  mov rdi, qword[rbp-48] ; rdi = destination ptr
  .template_copy_loop:
  cmp rax, _with_template_macro_end
  jge .template_copy_loop_break

  mov cl, byte[rax]
  mov byte[rdi], cl

  inc rdi
  inc rax
  jmp .template_copy_loop
  .template_copy_loop_break:

  ;; Push our template macro to the macro stack
  sub rsp, 16
  mov qword[rsp], 8
  mov rax, qword[rbp-48]
  mov qword[rsp+8], rax
  mov rdi, qword[macro_stack_structural]  ; macro stack
  mov rsi, qword[r12+8]          ; macro name
  mov rdx, rsp                    ; code
  call kv_stack_push
  add rsp, 16

  ;; Push our template macro's id to the id byte buffer
  mov rdi, r13
  mov rsi, rax
  call byte_buffer_push_int64

  ;; Modify our macro code to replace it's pointer to the definition data
  mov rcx, qword[rbp-48]
  mov rax, qword[rbp-56]
  mov qword[rcx+(_with_template_macro_end - _with_template_macro)], rax

  add rsp, 24
  pop rbx
  pop r15
  pop r14
  pop r13
  pop r12
  pop rbp
  ret

;;; _with_push_macros(def-list-parray*, id_byte_buffer*, data_byte_buffer*)
_with_push_macros:
  push rbp
  mov rbp, rsp
  push r12
  push r13
  push r14
  push r15
  push rbx
  sub rsp, 8

  mov r12, rdi ; r12 = definition list parray
  mov r13, rsi ; r13 = macro id byte buffer
  mov r14, rdx ; r14 = data byte buffer

  mov rdi, qword[rbp+8]
  mov rsi, 16
  mov rdx, 2
  mov rcx, 0
  call write_as_base

  mov rdi, 10
  mov rsi, 2
  call write_char

  ;; Error if our input is not a parray
  cmp qword[r12], 0
  jl .is_parray

  mov rdi, with_definitions_not_list_error
  mov rsi, with_definitions_not_list_error_len
  call error_exit

  .is_parray:

  ;; Iterate over definitions in definition parray
  mov rbx, r12
  add rbx, 8 ; move past length

  mov r15, qword[r12]
  not r15 ; r15 = definition count
  .definition_loop:
  cmp r15, 0
  jle .definition_loop_break

  ;; Create greedy expansion byte buffer
  call byte_buffer_new
  mov qword[rbp-48], rax ; qword[rbp-48] = greedy expansion buffer

  ;; Greedy macroexpand the definition
  mov rdi, qword[rbx] ; rdi = pointer to definition parray
  mov rsi, qword[rbp-48]
  mov rdx, 2 ; greedy
  call structural_macro_expand

  ;; Push our access/reference macro referencing the byte buffer
  mov rdi, rax ; rdi = greedy macro expansion of definition
  mov rsi, r13
  mov rdx, r14
  call _with_push_macro

  ;; Free the greedy expansion byte buffer
  mov rdi, qword[rbp-48]
  call byte_buffer_free

  add rbx, 8
  dec r15
  jmp .definition_loop
  .definition_loop_break:

  add rsp, 8
  pop rbx
  pop r15
  pop r14
  pop r13
  pop r12
  pop rbp
  ret

;;; with(structure*, output_byte_buffer*) -> output buf relptr
with_:
  push rbp
  mov rbp, rsp
  push r12
  push r13
  push r14
  push r15
  push rbx
  sub rsp, 24

  mov r12, rdi ; r12 = input structure
  mov r13, rsi ; r13 = output byte buffer

  ;; Return -1 for no expansion if we have < 3 elements in our input structure
  cmp qword[r12], -4
  mov rax, -1
  jg .epilogue

  ;; Init byte buffers for shy macroexpand, to store our data entries, to store our macro ids
  mov rax, byte_buffer_new
  call rax
  mov r14, rax ; r14 = shy macroexpand buffer

  mov rax, byte_buffer_new
  call rax
  mov r15, rax ; r15 = data entry buffer

  mov rax, byte_buffer_new
  call rax
  mov rbx, rax ; rbx = macro id buffer

  ;; Shy macroexpand our definition list
  mov rdi, qword[r12+16]
  mov rsi, r14
  mov rdx, 1 ; shy
  mov rax, structural_macro_expand
  call rax
  mov qword[rbp-48], rax ; qword[rbp-48] = shy expansion of definition list

  ;; Push macros for accessing/referencing our data
  mov rdi, qword[rbp-48] ; shy expansion of definition list
  mov rsi, rbx           ; id byte buffer
  mov rdx, r15           ; data byte buffer
  mov rax, _with_push_macros
  call rax

  ;; Greedy macroexpand our output (3rd item in input structure parray)
  mov rdi, qword[r12+24] ; 3rd item from input structure
  mov rsi, r13           ; output byte buffer
  mov rdx, 2             ; greedy
  mov rax, structural_macro_expand
  call rax
  mov qword[rbp-56], rax ; qword[rbp-56] = abs pointer to output

  mov rdi, r13 ; output byte buffer
  mov rax, byte_buffer_get_buf
  call rax
  sub qword[rbp-56], rax ; qword[rbp-56] = relative pointer to result

  ;; Pop access/reference macros by ids in id byte buffer
  mov rdi, rbx
  mov rax, byte_buffer_get_data_length
  call rax
  mov qword[rbp-64], rax

  .pop_loop:
  cmp qword[rbp-64], 0
  jle .pop_loop_break

  mov rdi, rbx
  mov rax, byte_buffer_pop_int64
  call rax

  push rax
  sub rsp, 8

  mov rdi, qword[macro_stack_structural] ; macro stack
  mov rsi, rax
  call kv_stack_value_by_id
  mov rdi, qword[rax+8]
  call free

  add rsp, 8
  pop rax

  mov rdi, qword[macro_stack_structural] ; macro stack
  mov rsi, rax
  call kv_stack_pop_by_id

  sub qword[rbp-64], 8
  jmp .pop_loop
  .pop_loop_break:

  ;; Free each byte buffer in data byte buffer (it's a buffer of pointers to byte buffers)

  ;; Free id list byte buffer, data byte buffer, and shy macroexpand byte buffer
  mov rdi, rbx
  mov rax, byte_buffer_free
  call rax

  mov rdi, r15
  mov rax, byte_buffer_free
  call rax

  mov rdi, r14
  mov rax, byte_buffer_free
  call rax

  ;; Return buffer-relative pointer to result
  mov rax, qword[rbp-56]

  .epilogue:
  add rsp, 24
  pop rbx
  pop r15
  pop r14
  pop r13
  pop r12
  pop rbp
  ret
with_end:
