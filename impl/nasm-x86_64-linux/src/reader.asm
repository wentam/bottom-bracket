section .text
global fn_read
global fn__read ; for reader macros
global fn_free_read_result
global fn_dump_read_result_buffer
global fn_dump_read_result
extern fn_read_char
extern fn_malloc
extern fn_realloc
extern fn_free
extern fn_write_char
extern fn_write
extern fn_exit
extern fn_error_exit
extern BUFFERED_READER_EOF
extern fn_assert_stack_aligned
extern fn_bindump
extern fn_write_as_base

extern fn_buffered_fd_reader_new
extern fn_buffered_fd_reader_free
extern fn_buffered_fd_reader_read_byte
extern fn_buffered_fd_reader_peek_byte
extern fn_buffered_fd_reader_consume_leading_whitespace

extern fn_byte_buffer_new
extern fn_byte_buffer_free
extern fn_byte_buffer_push_int64
extern fn_byte_buffer_push_byte
extern fn_byte_buffer_dump_buffer
extern fn_byte_buffer_get_write_ptr
extern fn_byte_buffer_get_data_length
extern fn_byte_buffer_get_buf
extern fn_byte_buffer_bindump_buffer

extern macro_stack_call_by_name
extern macro_stack_reader

section .rodata
;;; Syscall numbers
sys_write: equ 0x01
sys_read:  equ 0x00
sys_exit:  equ 0x3c

stdin_fd:  equ 0
stdout_fd: equ 1
stderr_fd: equ 2

%define READ_BUFFER_SIZE 4096
%define OUTPUT_BUFFER_START_SIZE 16
%define NEWLINE 10
%define TAB 9

unexpected_eof_str: db "ERROR: Unexpected EOF while reading (did you give me any input?)",10
unexpected_eof_str_len: equ $ - unexpected_eof_str

unexpected_paren_str: db "ERROR: Unexpected ')' while reading",10
unexpected_paren_str_len: equ $ - unexpected_paren_str

unexpected_eof_parray_str: db "ERROR: Unexpected EOF while reading parray (are your parenthesis mismatched?)",10
unexpected_eof_parray_str_len: equ $ - unexpected_eof_parray_str

unexpected_eof_barray_str: db "ERROR: Unexpected EOF while reading barray",10
unexpected_eof_barray_str_len: equ $ - unexpected_eof_barray_str

section .text

;;; read(fd) -> ptr
;;;   Reads one expression from the file descriptor into internal representation
;;;
;;;   You must free the result with free_read_result when done.
fn_read:
  push r14 ; Preserve
  push r13 ; Preserve
  push r12 ; Preserve

  %ifdef ASSERT_STACK_ALIGNMENT
  call fn_assert_stack_aligned
  %endif

  mov r12, rdi ; We'll need this later but are about to clobber it

  ;; Create new buffered reader
  mov rdi, r12
  call fn_buffered_fd_reader_new
  mov r13, rax ; r13 = new buffered reader

  ;; Allocate output byte buffer
  call fn_byte_buffer_new
  mov r14, rax

  ;; Call recursive implementation
  mov rdi, r13
  mov rsi, r14
  call fn__read
  push rax
  sub rsp, 8

  ;; Free buffered reader
  mov rdi, r13
  call fn_buffered_fd_reader_free

  ;; Append a pointer to the byte buffer struct at the end of the data.
  ;; This is needed to free the buffer later (and useful for any other function
  ;; that wants to go from read result back to byte buffer struct)
  mov rdi, r14
  mov rsi, 0
  call fn_byte_buffer_push_int64

  ;; TODO: lock writes in the byte buffer so nothing can invalidate any
  ;; pointers from here forward?

  ;; Overwrite the int64 we just wrote with the actual pointer
  ;; now that it's done resizing (so we don't invalidate our own pointer by
  ;; writing)
  mov rdi, r14
  call fn_byte_buffer_get_data_length
  mov rdi, rax

  push rdi
  push rdi
  mov rdi, r14
  call fn_byte_buffer_get_buf
  pop rdi
  pop rdi
  mov qword[rax+rdi-8], r14

  add rsp, 8

  pop rax
  mov r12, rax

  ;; r12 contains a relative pointer, we need to return absolute.
  mov rdi, r14
  call fn_byte_buffer_get_buf
  add rax, r12

  ;; Convert relative pointers to absolute
  push rax
  sub rsp, 8
  mov rdi, rax
  mov rsi, r14
  call fn__relative_to_abs
  add rsp, 8
  pop rax

  pop r12 ; Restore
  pop r13 ; Restore
  pop r14 ; Restore
  ret

;;; free_read_result(*read_result)
;;;   Frees all memory associated with a call to read().
fn_free_read_result:
  sub rsp, 8
  call fn__get_byte_buf_from_read_result
  mov rdi, rax
  call fn_byte_buffer_free
  add rsp, 8
  ret

;;; _relative_to_abs(*read_result, *byte_buffer)
;;;   Recursively modifies pointers in a read result that uses buffer-relative
;;;   pointers (like from _read) to convert them to absolute.
;;;
;;;   We need this because if _read was to use absolute pointers further
;;;   writes would invalidate the pointers. _read produces relative pointers
;;;   and we convert them to absolute right before we return to the user.
fn__relative_to_abs:
  push r12
  push r13
  push r14
  push r15
  sub rsp, 8

  mov r12, rdi ; read result ptr
  mov r13, rsi ; byte buffer

  ;; Start of actual buffer -> r14
  mov rdi, r13
  call fn_byte_buffer_get_buf
  mov r14, rax

  %ifdef ASSERT_STACK_ALIGNMENT
  call fn_assert_stack_aligned
  %endif

  mov r15, qword[r12] ; Length of parray/barray -> r15

  ;; If this is a barray, do nothing
  cmp r15, 0
  jge _relative_to_abs_epilogue

  neg r15 ; Make parray length positive

  ;; If this is an parray, recursively convert
  add r12, 8 ; move past parray length

  _relative_to_abs_convert_loop:
    cmp r15, 0
    je _relative_to_abs_convert_loop_break

    add qword[r12], r14

    mov rdi, qword[r12]
    mov rsi, r13
    call fn__relative_to_abs

    add r12, 8
    dec r15
    jmp _relative_to_abs_convert_loop


  _relative_to_abs_convert_loop_break:

  _relative_to_abs_epilogue:
  add rsp, 8
  pop r15
  pop r14
  pop r13
  pop r12
  ret

;;; _read(*buffered_fd_reader, *output_buffer) -> ptr
;;;   Recursive implementation of read(). Return a *buffer-relative* pointer to
;;;   the result.
fn__read:
  push r12
  push r13
  push r14
  push r15
  sub rsp, 8
  mov r12, rdi ; Preserve buffered reader
  mov r14, rsi ; Preserve output buffer

  %ifdef ASSERT_STACK_ALIGNMENT
  call fn_assert_stack_aligned
  %endif

  ;; Consume all the leading whitespace (this also peeks)
  mov rdi, r12
  call fn_buffered_fd_reader_consume_leading_whitespace

  ;; If we got EOF, Error
  cmp rax, BUFFERED_READER_EOF
  je __read_unexpected_eof

  ;; If we got a parray end, error
  ;;cmp rax, ')'
  ;;je __read_unexpected_closing_paren
  ;; TODO recreate this error in barray parser/reader macro?
  ;; doesn't make sense here now that we're macro-based

  ;; Try to call a reader macro by this char's name
  ;; TODO support multi-char reader macros
  push rax
  mov rcx, 1
  push rcx
  mov rdx, r12
  mov rcx, r14
  mov rdi, qword[macro_stack_reader]
  mov rsi, rsp
  call macro_stack_call_by_name
  pop rcx
  pop rcx

  cmp rdx, 0
  jne __read_epilogue

  ;; Prepare arguments for _read_barray
  mov rdi, r12
  mov rsi, r14

  __read_barray:
  call fn__read_barray
  jmp __read_epilogue ; Return. rax is already a pointer to the barray.

  __read_unexpected_eof:
  mov rdi, unexpected_eof_str
  mov rsi, unexpected_eof_str_len
  call fn_error_exit

  __read_unexpected_closing_paren:
  mov rdi, unexpected_paren_str
  mov rsi, unexpected_paren_str_len
  call fn_error_exit

  __read_epilogue:

  add rsp, 8
  pop r15
  pop r14
  pop r13
  pop r12
  ret

;;; _read_barray(*buffered_fd_reader, *output_buffer) -> ptr
;;;   Reads a barray from the buffered reader.
;;;   Writes the barray to the output buffer.
;;;
;;;   Returns a buffer-relative pointer to the barray.
fn__read_barray:
  push r12
  push r14
  push r15
  push rbx
  push r13

  %ifdef ASSERT_STACK_ALIGNMENT
  call fn_assert_stack_aligned
  %endif

  mov r12, rdi ; Preserve buffered reader
  mov r14, rsi ; Preserve output buffer

  ;; Consume all the leading whitespace
  mov rdi, r12
  call fn_buffered_fd_reader_consume_leading_whitespace

  cmp rax, BUFFERED_READER_EOF
  jne __read_barray_no_eof

  mov rdi, unexpected_eof_barray_str
  mov rsi, unexpected_eof_barray_str_len
  call fn_error_exit

  __read_barray_no_eof:

  ;; Write length placeholder
  mov rdi, r14
  mov rsi, 0
  call fn_byte_buffer_push_int64

  ;; Read characters until the end of the barray
  mov rbx, 0 ;; char counter
  __read_barray_char:
  ;; Peek the next char - if it's '(', ')' or whitespace, we're done.
  ;; We cannot consume because consuming '(' or ')' would be damaging.
  mov rdi, r12 ; buffered reader
  call fn_buffered_fd_reader_peek_byte
  cmp rax, ')'
  je __read_barray_finish
  cmp rax, '('
  je __read_barray_finish
  cmp rax, ' '
  je __read_barray_finish
  cmp rax, BUFFERED_READER_EOF
  je __read_barray_finish
  cmp rax, NEWLINE
  je __read_barray_finish
  cmp rax, TAB
  je __read_barray_finish

  ;; Read the next char
  mov rdi, r12
  call fn_buffered_fd_reader_read_byte
  mov r15, rax

  ;; Output this char to the buffer
  mov rdi, r14
  mov rsi, r15
  call fn_byte_buffer_push_byte

  inc rbx

  ;; Repeat
  jmp __read_barray_char

  __read_barray_finish:
  ;; Update barray length placeholder

  mov rdi, r14
  call fn_byte_buffer_get_data_length ; Get data length
  mov r12, rax

  mov rdi, r14
  call fn_byte_buffer_get_buf         ; Get data
  mov r13, rax
  add rax, r12                        ; Buffer pointer forward to write pos

  sub rax, rbx                      ; Subtract whatever we just wrote
  sub rax, 8                        ; Subtract our placeholder length
  mov qword[rax], rbx               ; Write our length

  sub rax, r13 ; We want to return a relative pointer

  pop r13
  pop rbx
  pop r15
  pop r14
  pop r12
  ret

;;; dump_read_result_buffer(*reader_result, fd, base)
;;;   bindumps a read result's backing buffer to fd with base.
fn_dump_read_result_buffer:
  push r12
  push r13
  sub rsp, 8

  mov r12, rsi ; fd
  mov r13, rdx ; base

  %ifdef ASSERT_STACK_ALIGNMENT
  call fn_assert_stack_aligned
  %endif

  ;mov rdi, rdi
  call fn__get_byte_buf_from_read_result
  mov rdi, rax
  mov rsi, r12
  mov rdx, r13
  call fn_byte_buffer_bindump_buffer

  add rsp, 8
  pop r13
  pop r12
  ret

;; dump_read_result(*reader_result, fd, base)
;;   bindumps a read result
fn_dump_read_result:
  push r12
  push r13
  push r14
  push r15
  sub rsp, 8
  mov r12, rdi ; reader result
  mov r13, rsi ; fd
  mov r14, rdx ; base

  %ifdef ASSERT_STACK_ALIGNMENT
  call fn_assert_stack_aligned
  %endif

  ;; Work out how many bytes to dump
  mov r15, 0 ; length in bytes
  mov rax, qword[r12]
  cmp rax, 0
  jl _parray_buf

  _barray_buf:
  add r15, 8 ; the length itself
  add r15, rax ; each char is one byte, so just add it
  jmp _length_calculated

  _parray_buf:
  neg rax ; parray lengths are negative, make it positive
  add r15, 8 ; the length itself
  imul rax, 8
  add r15, rax
  ;jmp _length_calculated

  _length_calculated:

  mov rdi, r12
  mov rsi, r15
  mov rdx, r13
  mov rcx, r14
  call fn_bindump

  add rsp, 8
  pop r15
  pop r14
  pop r13
  pop r12
  ret


;;; _get_byte_buf_from_read_result(*reader_result) -> *byte_buffer
;;;   Given a result turned by read(), returns a pointer to it's original
;;;   backing buffer.
fn__get_byte_buf_from_read_result:
  push r12
  mov r12, rdi ; reader result

  %ifdef ASSERT_STACK_ALIGNMENT
  call fn_assert_stack_aligned
  %endif

  mov rax, qword[r12]
  cmp rax, 0
  jl parray_buf

  barray_buf:
  add r12, 8   ; move past the length
  mov rax, qword[r12+rax]
  jmp get_byte_buf_epilogue

  parray_buf:
  neg rax ; parray lengths are negative, invert
  add r12, 8 ; move past the length
  imul rax, 8
  mov rax, qword[r12+rax]
  ;jmp get_byte_buf_epilogue


  get_byte_buf_epilogue:
  pop r12
  ret
