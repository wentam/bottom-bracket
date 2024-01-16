section .tex
global macro_stack_new
global macro_stack_free
global macro_stack_push
global macro_stack_pop
global macro_stack_pop_by_name
global macro_stack_peek
global macro_stack_peek_by_name
global macro_stack_bindump_buffers
global macro_stack_call_by_name

extern fn_malloc
extern fn_free

extern fn_byte_buffer_new
extern fn_byte_buffer_free
extern fn_byte_buffer_push_byte
extern fn_byte_buffer_push_int64
extern fn_byte_buffer_get_data_length
extern fn_byte_buffer_bindump_buffer
extern fn_byte_buffer_get_buf
extern fn_byte_buffer_pop_bytes
extern fn_byte_buffer_pop_int64
extern fn_byte_buffer_read_int64
extern fn_byte_buffer_peek_int64
extern fn_byte_buffer_delete_bytes

extern fn_barray_equalp
extern fn_write_char
extern fn_write_as_base
extern fn_bindump
extern fn_assert_stack_aligned

section .rodata

section .text

;;; TODO should you 'push' a macro definition struct instead?
;;; Seems like that might be a more consistant interface,
;;; but maybe harder to use. Needs to be thought about carefully as
;;; this is a public interface.
;;;
;;; TODO should the macro definition code optionally be a pointer specified
;;; as [-length, ptr]? Sometimes there's no reason to copy the macro

;;; struct macro_definition {
;;;   size_t  name_length
;;;   char    name[name_length] // flat in struct
;;;   size_t  code_length;
;;;   char    code[code_length] // flat in struct
;;; }

;;; struct macro_stack {
;;;   byte_buffer* pbuffer;         // array of pointers to macro definitions
;;;   byte_buffer* dbuffer;         // macro definitions
;;; }

%define MACRO_STACK_PBUFFER_OFFSET  0
%define MACRO_STACK_DBUFFER_OFFSET 8

%define MACRO_STACK_STRUCT_SIZE 16

;;; macro_stack_new()
;;;   Makes a new macro stack.
;;;
;;;   You must free the macro stack with macro_stack_free when done.
macro_stack_new:
  push r12
  mov rdi, MACRO_STACK_STRUCT_SIZE
  call fn_malloc
  mov r12, rax ; move new struct into r12

  call fn_byte_buffer_new
  mov qword[r12+MACRO_STACK_PBUFFER_OFFSET], rax

  call fn_byte_buffer_new
  mov qword[r12+MACRO_STACK_DBUFFER_OFFSET], rax

  mov rax, r12 ; Return new struct
  pop r12
  ret

;;; macro_stack_free(*macro_stack)
;;;   Frees a macro stack.
macro_stack_free:
  push r12
  mov r12, rdi ; the macro stack struct

  %ifdef ASSERT_STACK_ALIGNMENT
  call fn_assert_stack_aligned
  %endif

  mov rdi, qword[r12+MACRO_STACK_PBUFFER_OFFSET]
  call fn_byte_buffer_free

  mov rdi, qword[r12+MACRO_STACK_DBUFFER_OFFSET]
  call fn_byte_buffer_free

  mov rdi, r12
  call fn_free
  pop r12
  ret

;;; macro_stack_push(*macro_stack, *macro_name, *code)
;;;   Pushes a macro onto the macro stack.
;;;
;;;   *macro_name should be a barray of the desired macro name.
;;;   The memory at *macro_name doesn't need to remain valid after this returns.
;;;
;;;   *code should be a barray of the macro code.
;;;   The memory at *code doesn't need to remain valid after this returns.
macro_stack_push:
  push r12
  push r13
  push r14
  push r15
  push rbx
  mov r15, rdi ; Pointer to macro stack struct
  mov r12, rsi ; Pointer to macro name barray
  mov r13, qword[r12] ; Length of macro name
  mov r14, rdx ; Pointer to code barray

  %ifdef ASSERT_STACK_ALIGNMENT
  call fn_assert_stack_aligned
  %endif


  ;; Save the current data length in dbuffer to use as a relative pointer
  ;; to the macro definition
  mov rdi, qword[r15+MACRO_STACK_DBUFFER_OFFSET]
  call fn_byte_buffer_get_data_length
  mov rbx, rax ; rbx = relative pointer to the code we're about to write

  ;; Copy the name barray into the dbuffer
  push r14
  sub rsp, 8

  mov r14, r12
  add r13, 8 ; Include length
  .barray_cp_loop:
    cmp r13, 0
    je .barray_cp_loop_break

    mov rdi, qword[r15+MACRO_STACK_DBUFFER_OFFSET]
    mov sil, byte[r14]
    call fn_byte_buffer_push_byte

    dec r13
    inc r14
    jmp .barray_cp_loop

  .barray_cp_loop_break:

  add rsp, 8
  pop r14

  ;; Copy code barray into the dbuffer
  mov r13, qword[r14] ; length of macro code
  add r13, 8 ; We want to include length
  .code_cp_loop:
    cmp r13, 0
    je .code_cp_loop_break

    mov rdi, qword[r15+MACRO_STACK_DBUFFER_OFFSET]
    mov sil, byte[r14]
    call fn_byte_buffer_push_byte

    dec r13
    inc r14
    jmp .code_cp_loop

  .code_cp_loop_break:

  ;; Write a relative pointer to this definition into the pbuffer
  mov rdi, qword[r15+MACRO_STACK_PBUFFER_OFFSET]
  mov rsi, rbx
  call fn_byte_buffer_push_int64

  pop rbx
  pop r15
  pop r14
  pop r13
  pop r12
  ret

;;; macro_stack_pop(*macro_stack) -> *macro_definition
;;;   Removes the most recently pushed macro from the stack.
;;;
;;;   Returns a pointer to the macro definition in the format of
;;;   the macro_definition struct above. Pushing to the macro
;;;   stack invalidates the returned pointer (copy the data if you need
;;;   to keep it).
macro_stack_pop:
  push r12
  push r13
  push rbx
  push r14
  sub rsp, 8
  mov r12, rdi ; macro stack

  %ifdef ASSERT_STACK_ALIGNMENT
  call fn_assert_stack_aligned
  %endif

  ;; Pop pointer to this macro definition off pbuffer
  mov rdi, qword[r12+MACRO_STACK_PBUFFER_OFFSET]
  call fn_byte_buffer_pop_int64
  mov rbx, rax ; rbx = pointer to definition

  ;; Obtain name length from dbuffer via the pointer
  mov rdi, qword[r12+MACRO_STACK_DBUFFER_OFFSET]
  mov rsi, rbx
  call fn_byte_buffer_read_int64
  mov r14, rax

  ;; Obtain macro length from dbuffer via the pointer+name length+8
  mov rcx, rbx
  add rcx, r14
  add rcx, 8
  mov rdi, qword[r12+MACRO_STACK_DBUFFER_OFFSET]
  mov rsi, rcx
  call fn_byte_buffer_read_int64

  ;; Calculate total byte length of this macro definition from the above
  add r14, rax
  add r14, 16

  ;; Pop the bytes off the dbuffer
  mov rdi, qword[r12+MACRO_STACK_DBUFFER_OFFSET]
  mov rsi, r14
  call fn_byte_buffer_pop_bytes

  ;; rax is already our return value via byte_buffer_pop_bytes

  add rsp, 8
  pop r14
  pop rbx
  pop r13
  pop r12
  ret

;;; macro_stack_peek(*macro_stack) -> *macro_definition
;;;   Returns a pointer to the most recently pushed macro definition.
;;;
;;;   Any push or pop_by_name to the macro stack invalidates the returned
;;;   pointer.
macro_stack_peek:
  push r12
  push r13
  sub rsp, 8
  mov r12, rdi ; macro stack

  mov rdi, qword[r12+MACRO_STACK_DBUFFER_OFFSET]
  call fn_byte_buffer_get_buf
  mov r13, rax ; rax = pbuffer raw buffer pointer

  mov rdi, qword[r12+MACRO_STACK_PBUFFER_OFFSET]
  call fn_byte_buffer_peek_int64
  add rax, r13
  add rsp, 8
  pop r13
  pop r12
  ret

;;; macro_stack_pop_by_name(*macro_stack,*name_barray)
;;;   Removes the most recently pushed macro that matches the name barray.
;;;
;;;   Returns nothing.
;;;
;;;   TODO If no macros are found by the given name, returns 0 (NULL)
macro_stack_pop_by_name:
  push r12
  push r13
  push r14
  mov r13, rdi ; macro stack

  ;mov rdi, rdi
  ;mov rsi, rsi
  call macro_stack_peek_by_name
  mov r12, rax

  mov rdi, qword[r13+MACRO_STACK_DBUFFER_OFFSET]
  call fn_byte_buffer_get_buf
  mov r14, rax

  mov rdi, qword[r13+MACRO_STACK_DBUFFER_OFFSET]

  mov rdx, qword[r12]
  add rdx, qword[r12+rdx+8]
  add rdx, 16

  mov rsi, r12       ; index
  sub rsi, r14
  call fn_byte_buffer_delete_bytes
  pop r14
  pop r13
  pop r12
  ret

;;; macro_stack_peek_by_name(*macro_stack,*name_barray) -> *macro_definition
;;;   Finds the most recently pushed macro that matches the name barray.
;;;
;;;   Returns a pointer to the macro definition. Any push or pop_by_name
;;;   to the macro stack invalidates the returned pointer.
;;;
;;;   If no macros are found by the given name, returns 0 (NULL)
macro_stack_peek_by_name:
  push r12
  push r13
  push r14
  push r15
  push rbx

  mov r12, rdi ; macro stack struct
  mov r13, rsi ; name barray

  %ifdef ASSERT_STACK_ALIGNMENT
  call fn_assert_stack_aligned
  %endif

  mov r14, qword[r12+MACRO_STACK_PBUFFER_OFFSET] ; pbuffer

  ;; Get dbuffer buf
  mov rdi, qword[r12+MACRO_STACK_DBUFFER_OFFSET]
  call fn_byte_buffer_get_buf
  mov rbx, rax

  ;; Get pbuffer data length
  mov rdi, r14
  call fn_byte_buffer_get_data_length
  mov r12, rax

  ;; Work our way backwards through the pbuffer until we find a matching
  ;; name
  .find_name_loop:
  cmp r12, 0
  je .find_name_loop_nomatch

  sub r12, 8

  mov rdi, r14
  mov rsi, r12
  call fn_byte_buffer_read_int64
  mov r15, rax
  add r15, rbx

  mov rdi, r15
  mov rsi, r13
  call fn_barray_equalp
  cmp rax, 1
  je .find_name_loop_match

  jmp .find_name_loop

  .find_name_loop_nomatch:
  mov rax, 0
  jmp .epilogue

  .find_name_loop_match:
  mov rax, r15
  ;jmp .epilogue

  .epilogue:
  pop rbx
  pop r15
  pop r14
  pop r13
  pop r12
  ret

;;; macro_stack_call_by_name(*macro_stack, *name_barray, arg1, arg2, arg3)
;;;   Calls a macro in the macro stack by name. Returns the macro's
;;;   return value.
;;;
;;;   If the macro existed and we called it, rdx will be 1 at return. Else 0.
;;;
;;;   TODO support more than 3 arguments via stack?
macro_stack_call_by_name:
  push r12
  push r13
  push r14
  mov r12, rdx
  mov r13, rcx
  mov r14, r8

  call macro_stack_peek_by_name
  mov rdx, 0
  cmp rax, 0
  je .epilogue
  mov rcx, qword[rax] ; rdi = name length

  mov rdi, r12
  mov rsi, r13
  mov rdx, r14

  add rax, rcx ; macro_definition+name length
  add rax, 16  ; + width of both length integers
  call rax

  mov rdx, 1
  .epilogue:
  pop r14
  pop r13
  pop r12
  ret

;;; macro_stack_bindump_buffers(*macro_stack, fd, base)
;;;   bindump raw backing buffers for a macro stack (for debugging purposes)
macro_stack_bindump_buffers:
  push r12
  push r13
  push r14

  mov r12, rdi ; macro stack
  mov r13, rsi ; fd
  mov r14, rdx ; base

  %ifdef ASSERT_STACK_ALIGNMENT
  call fn_assert_stack_aligned
  %endif

  ;; bindump pbuffer
  mov rdi, qword[r12+MACRO_STACK_PBUFFER_OFFSET]
  mov rsi, r13
  mov rdx, r14
  call fn_byte_buffer_bindump_buffer

  ;; Newline
  mov rdi, 10
  mov rsi, r13
  call fn_write_char

  ;; bindump dbuffer
  mov rdi, qword[r12+MACRO_STACK_DBUFFER_OFFSET]
  mov rsi, r13
  mov rdx, r14
  call fn_byte_buffer_bindump_buffer

  pop r14
  pop r13
  pop r12
  ret
