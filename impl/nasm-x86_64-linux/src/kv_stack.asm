;;; Label stack: a stack-like data structure with key-value store properties
;;;   * optionally executable TODO make this actually optional and don't always allocate executable
;;;   * useful if you need a key-value store
;;;   * useful if you need a stack
;;;   * definitely useful when you want something with both properties. This is the
;;;     case with BB's macro system.

;;; TODO it might be beneficial to have a hashmap index for fast by-name lookups
;;; TODO it might be beneficial to have a hashmap index for fast by-id lookups

section .text
global kv_stack_new
global kv_stack_free
global kv_stack_push
global kv_stack_push_range
global kv_stack_pop
; TODO fixme first: global kv_stack_pop_by_key
global kv_stack_pop_by_id
global kv_stack_peek
global kv_stack_peek_by_key
global kv_stack_bindump_buffers
global kv_stack_value_by_key
global kv_stack_value_by_id
global kv_stack_top_value

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
extern byte_buffer_push_byte_n_times

extern barray_equalp
extern barray_new
extern write_char
extern write_as_base
extern bindump
extern assert_stack_aligned

section .rodata

section .text

;;; TODO instead of shifting stuff out of the dbuffer on every removal, we could possibly
;;; leave it alone until waste bytes >= 25%. Just update pbuffer.
;;;
;;; Once 25% threshold has past, run a batch compaction.
;;;
;;;  Do this if removals end up showing up in profiling.

;;; struct frame {
;;;   size_t  id
;;;   barray  key   // flat in struct
;;;   barray  value // flat in struct
;;; }

;;; TODO we should probably make the pbuffer store 4-byte and not 8-byte pointers.
;;; This is "active data" in memory and we want to make absolutely sure it fits in L1
;;; at all times.

;;; TODO we might want to make the value a fixed size upon creation or maybe even a fixed
;;; 8 bytes. Right now we only ever use them as pointers AFAIK.

;;; struct kv_stack {
;;;   byte_buffer* pbuffer;         // array of relpointers to frames in dbuffer
;;;   byte_buffer* dbuffer;         // frames
;;; }

%define KV_STACK_PBUFFER_OFFSET  0
%define KV_STACK_DBUFFER_OFFSET 8

%define KV_STACK_STRUCT_SIZE 16

;;; kv_stack_new()
;;;   Makes a new kv stack.
;;;
;;;   You must free the kv stack with kv_stack_free when done.
kv_stack_new:
  push r12
  mov rdi, KV_STACK_STRUCT_SIZE
  call malloc
  mov r12, rax ; move new struct into r12

  call byte_buffer_new
  mov qword[r12+KV_STACK_PBUFFER_OFFSET], rax

  call byte_buffer_new
  mov qword[r12+KV_STACK_DBUFFER_OFFSET], rax

  mov rax, r12 ; Return new struct
  pop r12
  ret

;;; kn_stack_free(*kv_stack)
;;;   Frees a kv stack.
kv_stack_free:
  push r12
  mov r12, rdi ; the kv stack struct

  %ifdef ASSERT_STACK_ALIGNMENT
  call assert_stack_aligned
  %endif

  mov rdi, qword[r12+KV_STACK_PBUFFER_OFFSET]
  call byte_buffer_free

  mov rdi, qword[r12+KV_STACK_DBUFFER_OFFSET]
  call byte_buffer_free

  mov rdi, r12
  call free
  pop r12
  ret

;;; kv_stack_push_range(*kv_stack, *key, *value_start, value_length)
;;;   Like kv_stack_push, but value is specified via pointer-and-length
;;;   instead of a barray.
;;;
;;;   Returns a unique id of the frame pushed
kv_stack_push_range:
  push r12
  push r13
  push r14
  push r15
  push rbx

  mov r12, rdi ; kv stack
  mov r13, rsi ; key
  mov r14, rdx ; value start
  mov r15, rcx ; value length

  ;; Create a new barray with this value in it
  mov rdi, r15
  mov rsi, r14
  call barray_new
  mov rbx, rax

  ;; Push the frame the normal barray way
  mov rdi, r12          ; kv stack
  mov rsi, r13          ; key
  mov rdx, rbx          ; value barray
  call kv_stack_push

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

;;; kv_stack_push(*kv_stack, *key, *value)
;;;   Pushes a frame onto the kv stack.
;;;
;;;   *key should be a barray
;;;   The memory at *key doesn't need to remain valid after this returns.
;;;
;;;   *value should be a barray of the value.
;;;   The memory at *value doesn't need to remain valid after this returns.
;;;
;;;   Returns a unique id of the frame
kv_stack_push:
  push r12
  push r13
  push r14
  push r15
  push rbx
  mov r15, rdi ; Pointer to kv stack struct
  mov r12, rsi ; Pointer to key barray
  mov r13, qword[r12] ; Length of key
  mov r14, rdx ; Pointer to value barray

  %ifdef ASSERT_STACK_ALIGNMENT
  call assert_stack_aligned
  %endif

  ;; Save the current data length in dbuffer to use as a relative pointer
  ;; to the frame
  mov rdi, qword[r15+KV_STACK_DBUFFER_OFFSET]
  call byte_buffer_get_data_length
  mov rbx, rax ; rbx = relative pointer to the value we're about to write

  ;; Grab current highest id used on this stack
  mov rdi, r15
  call kv_stack_highest_id
  inc rax
  push rax
  sub rsp, 8

  ;; Write id to dbuffer (highest id + 1)
  mov rdi, qword[r15+KV_STACK_DBUFFER_OFFSET]
  mov rsi, rax
  call byte_buffer_push_int64

  ;; Copy the key and value barrays into the dbuffer
  mov rdi, qword[r15+KV_STACK_DBUFFER_OFFSET]
  mov rsi, r12
  call byte_buffer_push_barray

  mov rdi, qword[r15+KV_STACK_DBUFFER_OFFSET]
  mov rsi, r14
  call byte_buffer_push_barray

  ;; Write a relative pointer to this definition into the pbuffer
  mov rdi, qword[r15+KV_STACK_PBUFFER_OFFSET]
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

;;; kv_stack_pop(*kv_stack) -> *frame
;;;   Removes the most recently pushed frame from the stack.
;;;
;;;   Returns a pointer to the frame in the format of
;;;   the frame struct above. Pushing to the kv stack
;;;   invalidates the returned pointer (copy the data if you need
;;;   to keep it).
kv_stack_pop:
  push r12
  push r13
  push rbx
  push r14
  sub rsp, 8
  mov r12, rdi ; kv stack

  %ifdef ASSERT_STACK_ALIGNMENT
  call assert_stack_aligned
  %endif

  ;; Pop pointer to this frame off pbuffer
  mov rdi, qword[r12+KV_STACK_PBUFFER_OFFSET]
  call byte_buffer_pop_int64
  mov rbx, rax ; rbx = pointer to definition

  ;; Obtain name length from dbuffer via the pointer
  mov rdi, qword[r12+KV_STACK_DBUFFER_OFFSET]
  mov rsi, rbx
  add rsi, 8 ; move past id
  call byte_buffer_read_int64
  mov r14, rax

  ;; Obtain frame length from dbuffer via the pointer+8(id)+8(name length int)+name length
  mov rcx, rbx
  add rcx, r14
  add rcx, 16
  mov rdi, qword[r12+KV_STACK_DBUFFER_OFFSET]
  mov rsi, rcx
  call byte_buffer_read_int64

  ;; Calculate total byte length of this frame from the above
  add r14, rax
  add r14, 24 ; (name length int)+(value length int)+(id)

  ;; Pop the bytes off the dbuffer
  mov rdi, qword[r12+KV_STACK_DBUFFER_OFFSET]
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
;;; _kv_stack_frame_len(*kv_stack, *frame_relptr) -> int64
_kv_stack_frame_len:
  push r12
  push r13
  push r14

  mov r12, rdi ; r12 = kv stack
  mov r13, rsi ; r13 = relptr

  ;; r14 = name length
  mov rdi, qword[r12+KV_STACK_DBUFFER_OFFSET]
  mov rsi, r13
  add rsi, 8 ; move past id
  call byte_buffer_read_int64
  mov r14, rax

  ;; Obtain length from dbuffer via the pointer+8(id)+8(name length int)+name length
  mov rdi, qword[r12+KV_STACK_DBUFFER_OFFSET]
  mov rsi, r13
  add rsi, r14
  add rsi, 16
  call byte_buffer_read_int64

  ;; Calculate final length
  add rax, r14
  add rax, 24 ; id+name_length_int+value_length_int

  pop r14
  pop r13
  pop r12
  ret

;;; kv_stack_value_by_id(*kv_stack, id) -> pointer to value barray
;;;   returns NULL if not found
kv_stack_value_by_id:
  push r12
  push r13
  push r14
  push r15
  push rbx

  mov r12, rdi ; r12 = kv stack
  mov r13, rsi ; r13 = id

  ;; Get length of pbuffer
  mov rdi, qword[r12+KV_STACK_PBUFFER_OFFSET]
  call byte_buffer_get_data_length
  mov r14, rax ; r14 = pbuffer data length

  ;; Walk backwards through the pbuffer
  .pbuffer_loop:
  cmp r14, 0
  jle .pbuffer_loop_notfound

  ;; Read an id
  mov rdi, qword[r12+KV_STACK_PBUFFER_OFFSET]
  mov rsi, r14
  sub rsi, 8
  call byte_buffer_read_int64
  mov rbx, rax ; rbx = pointer to frame

  mov rdi, qword[r12+KV_STACK_DBUFFER_OFFSET]
  mov rsi, rbx
  call byte_buffer_read_int64

  ;; Break if this id is a match
  cmp rax, r13
  je .pbuffer_loop_found

  sub r14, 8
  jmp .pbuffer_loop

  .pbuffer_loop_notfound:
  ;; ID not found, return NULL
  mov rax, 0
  jmp .epilogue

  .pbuffer_loop_found:

  mov rdi, qword[r12+KV_STACK_DBUFFER_OFFSET]
  call byte_buffer_get_buf
  add rbx, rax

  ; rbx now equals frame pointer
  add rbx, 8          ; move past id
  add rbx, qword[rbx] ; move past key
  add rbx, 8          ; move past key length

  mov rax, rbx

  .epilogue:
  pop rbx
  pop r15
  pop r14
  pop r13
  pop r12
  ret

;;; kv_stack_pop_by_id(*kv_stack, id)
;;;   Removes the frame on the stack with the given id. After you do this, your
;;;   id is invalid and may end up referring to a new, different frame pushed
;;;   to the stack (or no frame at all).
kv_stack_pop_by_id:
  push r12
  push r13
  push r14
  push r15
  push rbx
  push rbp
  sub rsp, 8

  mov r12, rdi ; r12 = kv stack
  mov r13, rsi ; r13 = id

  ;; Get length of pbuffer
  mov rdi, qword[r12+KV_STACK_PBUFFER_OFFSET]
  call byte_buffer_get_data_length
  mov r14, rax ; r14 = pbuffer data length
  mov r15, rax ; r15 = pbuffer data length (preserved for later)

  ;; Walk backwards through the pbuffer
  .pbuffer_loop:
  cmp r14, 0
  jle .pbuffer_loop_notfound

  ;; Read an id
  mov rdi, qword[r12+KV_STACK_PBUFFER_OFFSET]
  mov rsi, r14
  sub rsi, 8
  call byte_buffer_read_int64
  mov rbx, rax ; rbx = pointer to frame

  mov rdi, qword[r12+KV_STACK_DBUFFER_OFFSET]
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

  ;; Get size of frame
  mov rdi, r12
  mov rsi, rbx
  call _kv_stack_frame_len
  mov rbp, rax

  ;; Shift pointer in pbuffer out and subtract the frame size from
  ;; all pointers after in the stack as we go.
  mov rdi, qword[r12+KV_STACK_PBUFFER_OFFSET]
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
  mov rdi, qword[r12+KV_STACK_PBUFFER_OFFSET]
  mov rsi, 8
  call byte_buffer_pop_bytes

  ;mov rdi, rbp
  ;mov rsi, 10
  ;mov rdx, 2
  ;mov rcx, 0
  ;call write_as_base

  ;; Delete bytes out of dbuffer
  mov rdi, qword[r12+KV_STACK_DBUFFER_OFFSET]
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

;;; kv_stack_peek(*kv_stack) -> *frame
;;;   Returns a pointer to the most recently pushed frame.
;;;
;;;   Any push or pop_by_key to the kv stack invalidates the returned
;;;   pointer.
kv_stack_peek:
  push r12
  push r13
  sub rsp, 8
  mov r12, rdi ; kv stack

  mov rdi, qword[r12+KV_STACK_DBUFFER_OFFSET]
  call byte_buffer_get_buf
  mov r13, rax ; rax = pbuffer raw buffer pointer

  mov rdi, qword[r12+KV_STACK_PBUFFER_OFFSET]
  call byte_buffer_peek_int64
  add rax, r13
  add rsp, 8
  pop r13
  pop r12
  ret

;;; TODO I think this is broken: don't we need to update the pbuffer with
;;;      DO NOT USE THIS until fixed. See pop_by_id for a reference on how
;;;      to do this right.
;;;
;;; all new pointers after the deleted one?
;;; kv_stack_pop_by_key(*kv_stack,*name_barray)
;;;   Removes the most recently pushed frame that matches the name barray.
;;;
;;;   Returns nothing.
;;;
;;;   TODO If no macros are found by the given name, returns 0 (NULL)
kv_stack_pop_by_key:
  push r12
  push r13
  push r14
  mov r13, rdi ; kv stack

  ;mov rdi, rdi
  ;mov rsi, rsi
  call kv_stack_peek_by_key
  mov r12, rax

  mov rdi, qword[r13+KV_STACK_DBUFFER_OFFSET]
  call byte_buffer_get_buf
  mov r14, rax

  mov rdi, qword[r13+KV_STACK_DBUFFER_OFFSET]

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

;;; kv_stack_highest_id(*kv_stack)
;;;   Returns the highest id currently on this stack
kv_stack_highest_id:
  push r12
  push r13
  push r14

  %ifdef ASSERT_STACK_ALIGNMENT
  call assert_stack_aligned
  %endif

  mov r12, rdi                                   ; r12 = kv stack
  mov r13, qword[r12+KV_STACK_PBUFFER_OFFSET] ; r13 = pbuffer

  ;; Get pbuffer data length
  mov rdi, r13
  call byte_buffer_get_data_length
  cmp rax, 0
  je .epilogue ; If the kv stack is empty, return 0

  ;; Grab pointer to highest frame
  mov rdi, r13
  mov rsi, rax
  sub rsi, 8
  call byte_buffer_read_int64

  ;; Grab and return highest id
  mov rdi, qword[r12+KV_STACK_DBUFFER_OFFSET]
  mov rsi, rax
  call byte_buffer_read_int64

  .epilogue:
  pop r14
  pop r13
  pop r12
  ret

;;; kv_stack_peek_by_key(*kv_stack,*name_barray) -> *frame
;;;   Finds the most recently pushed frame that matches the name barray.
;;;
;;;   Returns a pointer to the frame. Any push or pop_by_key
;;;   to the kv stack invalidates the returned pointer.
;;;
;;;   If no frames are found by the given name, returns 0 (NULL)
kv_stack_peek_by_key:
  push r12
  push r13
  push r14
  push r15
  push rbx

  mov r12, rdi ; kv stack struct
  mov r13, rsi ; name barray

  %ifdef ASSERT_STACK_ALIGNMENT
  call assert_stack_aligned
  %endif

  mov r14, qword[r12+KV_STACK_PBUFFER_OFFSET] ; pbuffer

  ;; Get dbuffer buf
  mov rdi, qword[r12+KV_STACK_DBUFFER_OFFSET]
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

;;; kv_stack_value_by_key(*kv_stack, *key_barray)
;;;   Obtains a value by key, with higher-stack frames of the same key shadowing lower ones.
;;;
;;;   Returns a pointer to the value barray or NULL if it doesn't exist.
kv_stack_value_by_key:
  push r12

  call kv_stack_peek_by_key
  cmp rax, 0
  je .done
  mov rcx, qword[rax+8] ; rdi = name length
  add rax, rcx ; frame+name length
  add rax, 16  ; + width of name length integer + id

  .done:

  pop r12
  ret

;;; kv_stack_top_value(*kv_stack) -> pointer to higest frame's value barray
kv_stack_top_value:
  call kv_stack_peek
  mov rcx, qword[rax+8] ; rdi = name length
  add rax, rcx ; frame+name length
  add rax, 16  ; + width of name length int + id
  .done:
  ret

;;; kv_stack_bindump_buffers(*kv_stack, fd, base)
;;;   bindump raw backing buffers for a kv stack (for debugging purposes)
kv_stack_bindump_buffers:
  push r12
  push r13
  push r14

  mov r12, rdi ; kv stack
  mov r13, rsi ; fd
  mov r14, rdx ; base

  %ifdef ASSERT_STACK_ALIGNMENT
  call assert_stack_aligned
  %endif

  ;; bindump pbuffer
  mov rdi, qword[r12+KV_STACK_PBUFFER_OFFSET]
  mov rsi, r13
  mov rdx, r14
  call byte_buffer_bindump_buffer

  ;; Newline
  mov rdi, 10
  mov rsi, r13
  call write_char

  ;; bindump dbuffer
  mov rdi, qword[r12+KV_STACK_DBUFFER_OFFSET]
  mov rsi, r13
  mov rdx, r14
  call byte_buffer_bindump_buffer

  pop r14
  pop r13
  pop r12
  ret
