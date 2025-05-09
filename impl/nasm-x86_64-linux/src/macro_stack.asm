section .tex
global macro_stack_new
global macro_stack_free
global macro_stack_push
global macro_stack_push_range
global macro_stack_pop
; TODO fixme first global macro_stack_pop_by_name
global macro_stack_pop_by_id
global macro_stack_peek
global macro_stack_peek_by_name
global macro_stack_bindump_buffers
global macro_stack_call_by_name

extern malloc
extern free

extern byte_buffer_new
extern byte_buffer_free
extern byte_buffer_push_byte
extern byte_buffer_push_int64
extern byte_buffer_push_barray
extern byte_buffer_get_data_length
extern byte_buffer_bindump_buffer
extern byte_buffer_get_buf
extern byte_buffer_pop_bytes
extern byte_buffer_pop_int64
extern byte_buffer_read_int64
extern byte_buffer_peek_int64
extern byte_buffer_delete_bytes

extern barray_equalp
extern barray_new
extern write_char
extern write_as_base
extern bindump
extern assert_stack_aligned

section .rodata

section .text

;;; TODO should you 'push' a macro definition struct instead?
;;; Seems like that might be a more consistant interface,
;;; but maybe harder to use. Needs to be thought about carefully as
;;; this is a public interface.
;;;
;;; TODO should the macro definition code optionally be a pointer specified
;;; as [-length, ptr]? Sometimes there's no reason to copy the macro
;;;
;;; TODO instead of the stack directly containing the code, it would probably
;;; be much more efficient if we maintained a central pool of macro definitions
;;; that never go away - then simply push and pop pointers to them.

;;; struct macro_definition {
;;;   size_t  id
;;;   barray  name // flat in struct
;;;   barray  code // flat in struct
;;; }

;;; struct macro_stack {
;;;   byte_buffer* pbuffer;         // array of relative pointers to macro definitions
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
  call malloc
  mov r12, rax ; move new struct into r12

  call byte_buffer_new
  mov qword[r12+MACRO_STACK_PBUFFER_OFFSET], rax

  call byte_buffer_new
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
  call assert_stack_aligned
  %endif

  mov rdi, qword[r12+MACRO_STACK_PBUFFER_OFFSET]
  call byte_buffer_free

  mov rdi, qword[r12+MACRO_STACK_DBUFFER_OFFSET]
  call byte_buffer_free

  mov rdi, r12
  call free
  pop r12
  ret

;;; macro_stack_push_range(*macro_stack, *macro_name, *code_start, code length)
;;;   Like macro_stack_push, but code is specified via pointer-and-length
;;;   instead of a barray.
;;;
;;;   Returns a unique id of the macro pushed
macro_stack_push_range:
  push r12
  push r13
  push r14
  push r15
  push rbx

  mov r12, rdi ; macro stack
  mov r13, rsi ; macro name
  mov r14, rdx ; code start
  mov r15, rcx ; code length

  ;; Create a new barray with this code in it
  mov rdi, r15
  mov rsi, r14
  call barray_new
  mov rbx, rax

  ;; Push the macro the normal barray way
  mov rdi, r12          ; macro stack
  mov rsi, r13          ; macro name
  mov rdx, rbx          ; code barray
  call macro_stack_push

  push rax
  sub rsp, 8

  ;; Free the barray
  mov rdi, rbx
  call free

  add rsp, 8
  pop rax

  pop rbx
  pop r15
  pop r14
  pop r13
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
;;;
;;;   Returns a unique id of the macro pushed
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
  call assert_stack_aligned
  %endif

  ;; Save the current data length in dbuffer to use as a relative pointer
  ;; to the macro definition
  mov rdi, qword[r15+MACRO_STACK_DBUFFER_OFFSET]
  call byte_buffer_get_data_length
  mov rbx, rax ; rbx = relative pointer to the code we're about to write

  ;; Grab current highest id used on this stack
  mov rdi, r15
  call macro_stack_highest_id
  inc rax
  push rax
  sub rsp, 8

  ;; Write id to dbuffer (highest id + 1)
  mov rdi, qword[r15+MACRO_STACK_DBUFFER_OFFSET]
  mov rsi, rax
  call byte_buffer_push_int64

  ;; Copy the name and code barrays into the dbuffer
  mov rdi, qword[r15+MACRO_STACK_DBUFFER_OFFSET]
  mov rsi, r12
  call byte_buffer_push_barray

  mov rdi, qword[r15+MACRO_STACK_DBUFFER_OFFSET]
  mov rsi, r14
  call byte_buffer_push_barray

  ;; Write a relative pointer to this definition into the pbuffer
  mov rdi, qword[r15+MACRO_STACK_PBUFFER_OFFSET]
  mov rsi, rbx
  call byte_buffer_push_int64

  add rsp, 8
  pop rax

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
  call assert_stack_aligned
  %endif

  ;; Pop pointer to this macro definition off pbuffer
  mov rdi, qword[r12+MACRO_STACK_PBUFFER_OFFSET]
  call byte_buffer_pop_int64
  mov rbx, rax ; rbx = pointer to definition

  ;; Obtain name length from dbuffer via the pointer
  mov rdi, qword[r12+MACRO_STACK_DBUFFER_OFFSET]
  mov rsi, rbx
  mov rsi, 8 ; move past id
  call byte_buffer_read_int64
  mov r14, rax

  ;; Obtain macro length from dbuffer via the pointer+8(id)+8(name length int)+name length
  mov rcx, rbx
  add rcx, r14
  add rcx, 16
  mov rdi, qword[r12+MACRO_STACK_DBUFFER_OFFSET]
  mov rsi, rcx
  call byte_buffer_read_int64

  ;; Calculate total byte length of this macro definition from the above
  add r14, rax
  add r14, 24 ; (name length int)+(code length int)+(id)

  ;; Pop the bytes off the dbuffer
  mov rdi, qword[r12+MACRO_STACK_DBUFFER_OFFSET]
  mov rsi, r14
  call byte_buffer_pop_bytes

  ;; rax is already our return value via byte_buffer_pop_bytes

  add rsp, 8
  pop r14
  pop rbx
  pop r13
  pop r12
  ret

;;; TODO use this in pop
;;; _macro_stack_macro_definition_len(*macro_stack, *macro_definition_relptr) -> int64
_macro_stack_macro_definiton_len:
  push r12
  push r13
  push r14

  mov r12, rdi ; r12 = macro stack
  mov r13, rsi ; r13 = relptr

  ;; r14 = name length
  mov rdi, qword[r12+MACRO_STACK_DBUFFER_OFFSET]
  mov rsi, r13
  mov rsi, 8 ; move past id
  call byte_buffer_read_int64
  mov r14, rax

  ;; Obtain macro length from dbuffer via the pointer+8(id)+8(name length int)+name length
  mov rdi, qword[r12+MACRO_STACK_DBUFFER_OFFSET]
  mov rsi, r13
  add rsi, r14
  add rsi, 16
  call byte_buffer_read_int64

  ;; Calculate final length
  add rax, r14
  add rax, 24 ; id+name_length_int+code_length_int

  pop r14
  pop r13
  pop r12
  ret

;;; macro_stack_pop_by_id(*macro_stack, id)
;;;   Removes the macro on the stack with the given id. After you do this, your
;;;   id is invalid and may end up referring to a new, different macro pushed
;;;   to the stack (or no macro at all).
macro_stack_pop_by_id:
  push r12
  push r13
  push r14
  push r15
  push rbx
  push rbp
  sub rsp, 8

  mov r12, rdi ; r12 = macro stack
  mov r13, rsi ; r13 = id

  ;; Get length of pbuffer
  mov rdi, qword[r12+MACRO_STACK_PBUFFER_OFFSET]
  call byte_buffer_get_data_length
  mov r14, rax ; r14 = pbuffer data length
  mov r15, rax ; r15 = pbuffer data length (preserved for later)

  ;; Walk backwards through the pbuffer
  .pbuffer_loop:
  cmp r14, 0
  jle .pbuffer_loop_notfound

  ;; Read an id
  mov rdi, qword[r12+MACRO_STACK_PBUFFER_OFFSET]
  mov rsi, r14
  sub rsi, 8
  call byte_buffer_read_int64
  mov rbx, rax ; rbx = pointer to macro definiton

  mov rdi, qword[r12+MACRO_STACK_DBUFFER_OFFSET]
  mov rsi, rbx
  call byte_buffer_read_int64

  ;; Break if this id is a match
  cmp rax, r13
  je .pbuffer_loop_found

  sub r14, 8
  jmp .pbuffer_loop

  .pbuffer_loop_notfound:
  ;; ID not found, return
  jmp .epilogue

  .pbuffer_loop_found:

  sub r14, 8 ; r14 = relptr to pbuffer relptr

  ;; Get size of macro definition
  mov rdi, r12
  mov rsi, rbx
  call _macro_stack_macro_definiton_len
  mov rbp, rax

  ;; Shift pointer in pbuffer out and subtract the macro definition size from
  ;; all pointers after in the stack as we go.
  mov rdi, qword[r12+MACRO_STACK_PBUFFER_OFFSET]
  call byte_buffer_get_buf

  sub r15, 8 ; We're shifting, so we want to stop one short
  .pbuffer_shift_loop:
  cmp r14, r15
  jge .pbuffer_shift_loop_break
  mov rdi, qword[rax+r14+8]
  sub rdi, rbp
  mov qword[rax+r14], rdi
  add r14, 8
  jmp .pbuffer_shift_loop
  .pbuffer_shift_loop_break:

  ;; Shrink pbuffer by 8 bytes
  mov rdi, qword[r12+MACRO_STACK_PBUFFER_OFFSET]
  mov rsi, 8
  call byte_buffer_pop_bytes

  ;; Delete bytes out of dbuffer
  mov rdi, qword[r12+MACRO_STACK_DBUFFER_OFFSET]
  mov rsi, rbx
  mov rdx, rbp
  call byte_buffer_delete_bytes

  .epilogue:
  add rsp, 8
  pop rbp
  pop rbx
  pop r15
  pop r14
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
  call byte_buffer_get_buf
  mov r13, rax ; rax = pbuffer raw buffer pointer

  mov rdi, qword[r12+MACRO_STACK_PBUFFER_OFFSET]
  call byte_buffer_peek_int64
  add rax, r13
  add rsp, 8
  pop r13
  pop r12
  ret

;;; TODO I think this is broken: don't we need to update the pbuffer with
;;;      DO NOT USE THIS until fixed
;;;
;;; all new pointers after the deleted one?
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
  call byte_buffer_get_buf
  mov r14, rax

  mov rdi, qword[r13+MACRO_STACK_DBUFFER_OFFSET]

  mov rdx, qword[r12+8]
  add rdx, qword[r12+rdx+16]
  add rdx, 24

  mov rsi, r12       ; index
  sub rsi, r14
  call byte_buffer_delete_bytes
  pop r14
  pop r13
  pop r12
  ret

;;; macro_stack_highest_id(*macro_stack)
;;;   Returns the highest id currently on this stack
macro_stack_highest_id:
  push r12
  push r13
  push r14

  %ifdef ASSERT_STACK_ALIGNMENT
  call assert_stack_aligned
  %endif

  mov r12, rdi                                   ; r12 = macro stack
  mov r13, qword[r12+MACRO_STACK_PBUFFER_OFFSET] ; r13 = pbuffer

  ;; Get pbuffer data length
  mov rdi, r13
  call byte_buffer_get_data_length
  cmp rax, 0
  je .epilogue ; If the macro stack is empty, return 0

  ;; Grab pointer to highest macro definition
  mov rdi, r13
  mov rsi, rax
  sub rsi, 8
  call byte_buffer_read_int64

  ;; Grab and return highest id
  mov rdi, qword[r12+MACRO_STACK_DBUFFER_OFFSET]
  mov rsi, rax
  call byte_buffer_read_int64

  .epilogue:
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
  call assert_stack_aligned
  %endif

  mov r14, qword[r12+MACRO_STACK_PBUFFER_OFFSET] ; pbuffer

  ;; Get dbuffer buf
  mov rdi, qword[r12+MACRO_STACK_DBUFFER_OFFSET]
  call byte_buffer_get_buf
  mov rbx, rax

  ;; Get pbuffer data length
  mov rdi, r14
  call byte_buffer_get_data_length
  mov r12, rax

  ;; Work our way backwards through the pbuffer until we find a matching
  ;; name
  .find_name_loop:
  cmp r12, 0
  je .find_name_loop_nomatch

  sub r12, 8

  mov rdi, r14
  mov rsi, r12
  call byte_buffer_read_int64
  mov r15, rax
  add r15, rbx

  mov rdi, r15
  add rdi, 8 ; move past id
  mov rsi, r13
  call barray_equalp
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
  mov rcx, qword[rax+8] ; rdi = name length

  mov rdi, r12
  mov rsi, r13
  mov rdx, r14

  add rax, rcx ; macro_definition+name length
  add rax, 24  ; + width of both length integers + id
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
  call assert_stack_aligned
  %endif

  ;; bindump pbuffer
  mov rdi, qword[r12+MACRO_STACK_PBUFFER_OFFSET]
  mov rsi, r13
  mov rdx, r14
  call byte_buffer_bindump_buffer

  ;; Newline
  mov rdi, 10
  mov rsi, r13
  call write_char

  ;; bindump dbuffer
  mov rdi, qword[r12+MACRO_STACK_DBUFFER_OFFSET]
  mov rsi, r13
  mov rdx, r14
  call byte_buffer_bindump_buffer

  pop r14
  pop r13
  pop r12
  ret
