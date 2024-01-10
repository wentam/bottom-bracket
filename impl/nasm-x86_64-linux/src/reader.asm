section .text
global fn_read
global fn_free_read_result
global fn_dump_read_result_buffer
extern fn_read_char
extern fn_malloc
extern fn_realloc
extern fn_free
extern fn_write_char
extern fn_print
extern fn_exit
extern fn_error_exit
extern BUFFERED_READER_EOF
extern fn_assert_stack_aligned
extern fn_bindump

extern fn_buffered_reader_new
extern fn_buffered_reader_free
extern fn_buffered_reader_read_byte
extern fn_buffered_reader_peek_byte
extern fn_buffered_reader_consume_leading_whitespace

extern fn_byte_buffer_new
extern fn_byte_buffer_free
extern fn_byte_buffer_write_int64
extern fn_byte_buffer_write_byte
extern fn_byte_buffer_dump_buffer
extern fn_byte_buffer_get_write_ptr
extern fn_byte_buffer_bindump_buffer

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

unexpected_eof_array_str: db "ERROR: Unexpected EOF while reading array (are your parenthesis mismatched?)",10
unexpected_eof_array_str_len: equ $ - unexpected_eof_array_str

unexpected_eof_atom_str: db "ERROR: Unexpected EOF while reading atom",10
unexpected_eof_atom_str_len: equ $ - unexpected_eof_atom_str

section .text

;;; Structs:
;;;
;;; read_buffer {
;;;   char* read_ptr;              // Pointer to next byte to read
;;;   char* end_ptr;               // Pointer to end of valid data in buffer
;;;                                // (points to the first invalid byte)
;;;   char  buf[READ_BUFFER_SIZE]; // Buffer (flat in struct, not pointer)
;;; }
;;;
;;; output_buffer {
;;;   char*   write_ptr; // pointer to the next place to write
;;;   int64_t buflen;    // current length of the buffer. Must be power of 2
;;;   char buf[];        // Variable length, must be power of 2
;;;                      // (flat in struct, not pointer)
;;; }

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
  call fn_buffered_reader_new
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
  call fn_buffered_reader_free

  ;; Append a pointer to the byte buffer struct at the end of the data.
  ;; This is needed to free the buffer later (and useful for any other function
  ;; that wants to go from read result back to byte buffer struct)
  ;;
  ;; TODO: unsafe. __read should return a relative pointer so we
  ;; can write to the byte buffer without fear of realloc invalidating
  ;; the pointer in rax. We then translate that relative pointer to
  ;; an absolute pointer at return time.
  mov rdi, r14
  mov rsi, r14
  call fn_byte_buffer_write_int64

  add rsp, 8

  pop rax

  ;; TODO tmp dump the output buffer
  ;; TODO probably provide a function we can call from top-level for this
  ;;mov rdi, r14
  ;;mov rsi, stdout_fd
  ;;call fn_byte_buffer_dump_buffer

  pop r12 ; Restore
  pop r13 ; Restore
  pop r14 ; Restore
  ret

;;; free_read_result(*read_result)
;;;   Frees all memory associated with a call to read().
fn_free_read_result:
  call fn__get_byte_buf_from_read_result
  mov rdi, rax
  call fn_byte_buffer_free
  ret

;;; _read(*buffered_reader, *output_buffer) -> ptr
;;;   Recursive implementation of read()
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
  call fn_buffered_reader_consume_leading_whitespace

  ;; If we got EOF, Error
  cmp rax, BUFFERED_READER_EOF
  je __read_unexpected_eof

  ;; If we got an array end, error
  cmp rax, ')'
  je __read_unexpected_closing_paren

  ;; Prepare arguments for _read_array/_read_atom
  mov rdi, r12
  mov rsi, r14

  ;; If it looks like an array take array codepath, else atom codepath
  cmp rax, '('
  je __read_array

  __read_atom:
  call fn__read_atom
  jmp __read_epilogue ; Return. rax is already a pointer to the atom.

  __read_array:
  call fn__read_array
  jmp __read_epilogue ; Return; rax is already a pointer to the array

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

;;; _read_array(*buffered_reader, *output_buffer) -> ptr
;;;   Reads an array from the buffered reader
;;;   Writes the array to the output buffer
;;;
;;;   The first character in the buffer must be '('
;;;
;;;   Returns a pointer to the array.
fn__read_array:
  push r12
  push r14
  push r15
  push rbx
  sub rsp, 8

  %ifdef ASSERT_STACK_ALIGNMENT
  call fn_assert_stack_aligned
  %endif

  mov r12, rdi ; Preserve buffered reader
  mov r14, rsi ; Preserve output buffer

  ;; Consume the leading '(' TODO assert that it is actually '('
  mov rdi, r12
  call fn_buffered_reader_read_byte

  mov r15, 0 ; child counter
  __read_array_children:
  ;; Consume all whitespace
  mov rdi, r12
  call fn_buffered_reader_consume_leading_whitespace

  ;; Peek the next char (consume whitespace also peeks). If it's ')' we're done.
  cmp rax, ')'
  je __read_array_done

  ;; Error if it's EOF here
  cmp rax, BUFFERED_READER_EOF
  jne __read_array_no_eof

  mov rdi, unexpected_eof_array_str
  mov rsi, unexpected_eof_array_str_len
  call fn_error_exit

  __read_array_no_eof:

  ;; Read a child
  mov rdi, r12
  mov rsi, r14
  call fn__read

  ;; Push a pointer to this child onto the stack
  sub rsp, 8
  push rax

  inc r15 ; increment child counter

  jmp __read_array_children ; Next child

  __read_array_done:

  ;; Consume the trailing ')'
  mov rdi, r12
  call fn_buffered_reader_read_byte

  ;; Zero rbx to start tracking array size in bytes
  xor rbx, rbx

  ;; Write the array length
  mov rdi, r14
  mov rsi, r15
  call fn_byte_buffer_write_int64

  add rbx, 8 ; 8 bytes for array length

  ;; Output array pointers
  _output_array:
  cmp r15, 0
  je _output_array_break
  pop rsi
  add rsp, 8
  mov rdi, r14
  call fn_byte_buffer_write_int64

  add rbx, 8 ; 8 bytes for pointer

  dec r15
  jmp _output_array

  _output_array_break:

  ;; Set rax to the start of the array
  mov rdi, r14
  call fn_byte_buffer_get_write_ptr
  sub rax, rbx

  add rsp, 8
  pop rbx
  pop r15
  pop r14
  pop r12
  ret

;;; _read_atom(*buffered_reader, *output_buffer) -> ptr
;;;   Reads an atom from the buffered reader.
;;;   Writes the atom to the output buffer.
;;;
;;;   Returns a pointer to the atom.
fn__read_atom:
  push r12
  push r14
  push r15
  push rbx
  sub rsp, 8

  %ifdef ASSERT_STACK_ALIGNMENT
  call fn_assert_stack_aligned
  %endif

  mov r12, rdi ; Preserve buffered reader
  mov r14, rsi ; Preserve output buffer

  ;; Consume all the leading whitespace
  mov rdi, r12
  call fn_buffered_reader_consume_leading_whitespace

  cmp rax, BUFFERED_READER_EOF
  jne __read_atom_no_eof

  mov rdi, unexpected_eof_atom_str
  mov rsi, unexpected_eof_atom_str_len
  call fn_error_exit

  __read_atom_no_eof:

  ;; Write length placeholder
  mov rdi, r14
  mov rsi, 0
  call fn_byte_buffer_write_int64

  ;; Read characters until the end of the atom
  mov rbx, 0 ;; char counter
  __read_atom_char:
  ;; Peek the next char - if it's '(', ')' or whitespace, we're done.
  ;; We cannot consume because consuming '(' or ')' would be damaging.
  mov rdi, r12 ; buffered reader
  call fn_buffered_reader_peek_byte
  cmp rax, ')'
  je __read_atom_finish
  cmp rax, '('
  je __read_atom_finish
  cmp rax, ' '
  je __read_atom_finish
  cmp rax, BUFFERED_READER_EOF
  je __read_atom_finish
  cmp rax, NEWLINE
  je __read_atom_finish
  cmp rax, TAB
  je __read_atom_finish

  ;; Read the next char
  mov rdi, r12
  call fn_buffered_reader_read_byte
  mov r15, rax

  ;; Output this char to the buffer
  mov rdi, r14
  mov rsi, r15
  call fn_byte_buffer_write_byte

  inc rbx

  ;; Repeat
  jmp __read_atom_char

  __read_atom_finish:
  ;; Update atom length placeholder
  mov rdi, r14
  call fn_byte_buffer_get_write_ptr ; Get write pointer
  sub rax, rbx                      ; Subtract whatever we just wrote
  sub rax, 8                        ; Subtract our placeholder length
  not rbx                           ; Negate rbx as atoms should use -length
  inc rbx                           ; ^^^^^^^^
  mov qword[rax], rbx               ; Write our length
  ; rax should now contain a pointer to the start of our data, return

  add rsp, 8
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
  jl atom_buf

  array_buf:
  add r12, 8 ; move past the length
  imul rax, 8
  mov rax, qword[r12+rax]
  jmp get_byte_buf_epilogue

  atom_buf:
  dec rax
  not rax ; rax is now positive length
  add r12, 8   ; move past the length
  mov rax, qword[r12+rax]
  ;jmp get_byte_buf_epilogue

  get_byte_buf_epilogue:
  pop r12
  ret
