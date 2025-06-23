
;;;; Data structure with stack and key-value store-like propreties.
;;;;
;;;; You can look up a frame by key, and you'll get the highest frame that uses that key. Pushing
;;;; a new frame with that key masks the lower key until you pop it.
;;;;
;;;; Used for multiple things inside bottom bracket, but principally for tracking currently
;;;; active macros.

;;; * 2^16 max key length (64K)
;;; * Maximum of 2^16 (64K) entries with the same key (THIS WOULD BE A VERY WEIRD THING TO DO)
;;; * Maximum of 2^32 (~4 billion) entries. Each entry represents a user-defined macro,
;;; and I doubt any user will manage to write 4 billion macros and have them all on the stack
;;; at the same time.
;;; * Maximum of 4GB worth of keys+(6*entry_count). Practically this means probably around a maximum
;;;   of 100 million macros on the stack at a time, but it depends on key size.
;;;   * I think it's okay. chromium has probably around 200k-400k functions *total* across all TUs.
;;;     We support 100 million macros in a *single* TU. Thus completely reasonable limit.
;;;
;;; struct key {
;;;   u16 length
;;;   u8  bytes[length]
;;; }
;;;
;;; struct key_index_value {
;;;   u16 count
;;;   u32 frame_relptrs[count]; // In stack order. Later elements mask earlier elements.
;;; }
;;;
;;; struct frame {
;;;   u32 id;         // Negative id means this frame is dead/deleted.
;;;   u32 key_relptr; // technically optional since we'll always use the index
;;;   u64 value;
;;; }
;;;
;;; struct key_index_entry {
;;;   u32 key_relptr;   // Pointer to key struct in key_index_data.
;;;   u32 value_relptr; // Pointer to key_index_value struct in key_index_data;
;;; }
;;;
;;; struct key_index_bucket {
;;;   u8 entry_count;
;;;   key_index_entry entries[MAX_BUCKET_SIZE] // fixed size, rehash upon overflow
;;; }
;;;
;;; struct kv_stack {
;;;   byte_buffer* frames;         // Compact and re-index everything when waste is high.
;;;   key_index_bucket*  key_index_buckets;    // malloc'd
;;;   byte_buffer* key_index_data; // key_relptr and value_relptr values point into this buffer. Compacted when waste is high.
;;;
;;;   u64 stale_frame_bytes;       // Bytes in frames that are dead/stale so we know when to compact.
;;;   u64 stale_key_index_bytes;   // To decide when to compact keys
;;;   u64 key_index_bucket_count;
;;; }
;;;
;;;

;;; Notes:
;;; * To look up by id we just scan. In current code it winds up being the top frame 100% of the
;;; time, and we just use ID for durability.
;;; * Rule: The top frame cannot be a 'dead' frame, this would break stuff.
;;;   If removing the top frame, just shrink the frames buffer by the frame size.
;;;   This reduces compation drastically and makes accessing the top frame simpler.

global kv_stack_2_new
global kv_stack_2_free
global kv_stack_2_push
global kv_stack_2_top
global kv_stack_2_bindump_buffers
global _kv_stack_key_index_bucket

extern error_exit
extern malloc
extern free

extern byte_buffer_new
extern byte_buffer_free
extern byte_buffer_get_data_length
extern byte_buffer_extend
extern byte_buffer_get_buf
extern byte_buffer_push_int32
extern byte_buffer_push_barray_bytes
extern byte_buffer_bindump_buffer
extern write

extern bindump

section .rodata

not_pow2_err: db "ERROR: Non-power-of-2 bucket count requested for kv_stack. It must be a power of 2.",10
not_pow2_err_len: equ $ - not_pow2_err

no_top_err: db "ERROR: kv_stack_top called but there is no top frame (stack is empty).",10
no_top_err_len: equ $ - no_top_err

frames_str: db 10,"----------",10,"Frames",10,"----------",10
frames_str_len: equ $ - frames_str

buckets_str: db 10,"----------",10,"Buckets",10,"----------",10
buckets_str_len: equ $ - buckets_str

kid_str: db 10,"----------",10,"Key index data",10,"----------",10
kid_str_len: equ $ - kid_str

section .text

%define MAX_BUCKET_SIZE 4 ; Maximum of 255 for this.

struc kv_stack
  .frames:                 resq 1 ; byte_buffer* - compact and re-index me when waste is high
  .key_index_buckets:      resq 1 ; key_index_bucket*  - malloc'd array of key_index_bucket
  .key_index_data:         resq 1 ; byte_buffer* - key/val relptrs use this. Compact when needed.

  .stale_frame_bytes:      resq 1 ; Stale byte count in frames so we know when to compact
  .stale_key_index_bytes:  resq 1 ; Stale byte count in key_index_data so we know when to compact.
  .key_index_bucket_count: resq 1 ; Quantity of buckets in key index
endstruc

struc frame
  .id:         resd 1
  .key_relptr: resd 1
  .value:      resq 1
endstruc

;; Variable-sized
struc key_index_value
  .count: resw 1
  .frame_relptrs:
endstruc

struc key_index_entry
  .key_relptr:   resd 1
  .value_relptr: resd 1
endstruc

struc key_index_bucket
  .entry_count: resb 1
  .entries:     resb (key_index_entry_size*MAX_BUCKET_SIZE)
endstruc

;; (starting_key_index_bucket_count) -> kv_stack*
;;
;; Starting bucket count must be a power of 2
kv_stack_2_new:
  push r12
  push r13
  push r14

  mov r12, rdi ;; Starting bucket count for key index

  ;; Error if starting bucket count not a power of 2
  mov rax, r12
  dec rax
  and rax, r12
  jz .is_pow2

  mov rdi, not_pow2_err
  mov rsi, not_pow2_err_len
  call error_exit

  .is_pow2:

  ;; Create top-level kv_stack allocation
  mov rdi, kv_stack_size
  call malloc
  mov r13, rax ; kv_stack*

  ;; Initialize all kv_struct values
  mov qword[r13+kv_stack.stale_frame_bytes], 0
  mov qword[r13+kv_stack.stale_key_index_bytes], 0
  mov qword[r13+kv_stack.key_index_bucket_count], r12

  ;; Create frames byte buffer
  call byte_buffer_new
  mov qword[r13+kv_stack.frames], rax

  ;; Create key_index_buckets allocation
  mov rax, key_index_bucket_size
  mul r12
  mov rdi, rax
  mov r14, rax
  call malloc
  mov qword[r13+kv_stack.key_index_buckets], rax

  ;; Zero out key_index_buckets allocation
  mov rdi, rax
  mov rcx, r14
  xor rax, rax
  rep stosb

  ;; Create key_index_data byte buffer
  call byte_buffer_new
  mov qword[r13+kv_stack.key_index_data], rax

  mov rax, r13
  pop r14
  pop r13
  pop r12
  ret

;; (kv_stack*)
kv_stack_2_free:
  push r12

  mov r12, rdi ; kv_stack*

  ;; NOTE: we free in reverse order to kv_stack_new to be more friendly to our allocator

  ;; Free key_index_data byte buffer
  mov rdi, qword[r12+kv_stack.key_index_data]
  call byte_buffer_free

  ;; Free key_index_buckets allocation
  mov rdi, qword[r12+kv_stack.key_index_buckets]
  call free

  ;; Free frames byte buffer
  mov rdi, qword[r12+kv_stack.frames]
  call byte_buffer_free

  ;; Free top-level struct
  mov rdi, r12
  call free

  pop r12
  ret

;; (kv_stack*, barray* key, u64 value)
kv_stack_2_push:
  push rbp
  mov rbp, rsp
  push r12
  push r13
  push r14
  push r15
  push rbx
  sub rsp, 40

  mov r12, rdi ; kv_stack*
  mov r13, rsi ; barray* key
  mov r14, rdx ; u64 value

  .start:

  ;; Obtain the bucket* that this key should reside in
  mov rdi, r12                                        ; kv_stack*
  mov rsi, qword[r12+kv_stack.key_index_bucket_count] ; bucket_count
  mov rdx, r13                                        ; barray* key
  call _kv_stack_key_index_bucket
  mov r15, rax                                        ; r15 = bucket*

  ;; Work out at what relptr address our new frame will end up living so we can store it in index
  mov rdi, qword[r12+kv_stack.frames]
  call byte_buffer_get_data_length
  mov rbx, rax ; frame relptr

  ;; Zero out our key relptr slot
  mov qword[rbp-80], 0

  ;; If the key already exists in our key index, add our frame relptr to it's value.
  ;;
  ;; This means creating an entirely new key_index_value struct as a copy of the old one +
  ;; our new frame relptr, appending it to the key_index_data buffer, and marking the size of the
  ;; old one as stale in the buffer.
  ;;
  ;; We can't grow this struct in-place as there may be stuff after it.
  ;;
  ;; When it's at the tail we technically could, but this is not a code hotpath and thus
  ;; not really a concern to optimize right now.
  mov rdi, r12 ; kv_stack*
  mov rsi, r15 ; bucket*
  mov rdx, r13
  call _kv_stack_scan_bucket_for_key
  mov qword[rbp-48], rax ; key_index_entry*
  test rax, rax
  jz .no_existing_key

  .existing_key:

    ;; Get our existing key_index_value*
    mov rdi, qword[r12+kv_stack.key_index_data]
    call byte_buffer_get_buf

    mov rdi, qword[rbp-48] ; key_index_entry*

    mov ecx, dword[rdi+key_index_entry.key_relptr] ; key_relptr
    mov dword[rbp-80], ecx                         ; for .make_frame

    mov esi, dword[rdi+key_index_entry.value_relptr] ; value_relptr
    mov qword[rbp-72], rsi
    add qword[rbp-72], rax ; key_index_value*

    ;; Calculate size of existing key_index_value
    mov qword[rbp-64], 2 ; count
    mov rdi, qword[rbp-72] ; original key_index_value*
    xor rax, rax
    mov ax, word[rdi+key_index_value.count]
    shl rax, 2 ; *4
    add qword[rbp-64], rax ; qword[rbp-64] = size of original key_index_value

    ;; Obtain relptr to our new key_index_value
    mov rdi, qword[r12+kv_stack.key_index_data]
    call byte_buffer_get_data_length
    mov qword[rbp-56], rax ; relptr to our new key_index_value

    ;; Make space for our new key_index_value
    mov rdi, qword[r12+kv_stack.key_index_data]
    mov rsi, qword[rbp-64] ; size of original key_index_value
    call byte_buffer_extend
    ; rax = abs pointer to write our new key_index_value

    ;; Copy our original to the new location
    ;; rsi -> rdi #rcx
    mov rsi, qword[rbp-72]
    mov rdi, rax
    mov rcx, qword[rbp-64]
    rep movsb

    ;; Increment count
    inc word[rax+key_index_value.count]

    ;; Push our new frame relptr
    mov rdi, qword[r12+kv_stack.key_index_data]
    mov rsi, rbx
    call byte_buffer_push_int32

    ;; Update our key_index_entry's value relptr to point to our new one
    mov rdi, qword[rbp-48] ; key_index_entry*
    mov rsi, qword[rbp-56] ; relptr
    mov dword[rdi+key_index_entry.value_relptr], esi

    ;; Add our old key_index_value's size to our stale byte counter
    mov rsi, qword[rbp-64]
    add qword[r12+kv_stack.stale_key_index_bytes], rsi

    jmp .make_frame

  .no_existing_key:
    ;; The key doesn't exist in our key index. Add it.

    ;; If the bucket* (r15) is full, rehash and restart
    cmp byte[r15+key_index_bucket.entry_count], MAX_BUCKET_SIZE
    jl .room_in_bucket

    mov rdi, r12
    call _kv_stack_rehash_key_index
    jmp .start

    .room_in_bucket:

    ;; Grab a relptr to where our key_index_value and key will live in kv_stack.key_index_data
    mov rdi, qword[r12+kv_stack.key_index_data]
    call byte_buffer_get_data_length
    mov qword[rbp-48], rax ; relptr to our stuff in key_index_data

    ;; Add our key_index_value and key to kv_stack.key_index_data
    mov rdi, qword[r12+kv_stack.key_index_data]
    mov rsi, 8
    call byte_buffer_extend
    mov  word[rax]  , 1          ; key_index_value.count
    mov dword[rax+2], ebx        ; frame relptr
    mov rdx, qword[r13]
    mov  word[rax+6], dx ; key.length

    mov rdi, qword[r12+kv_stack.key_index_data]
    mov rsi, r13 ; key.bytes
    call byte_buffer_push_barray_bytes

    ;; Write our new key_index_entry to the bucket pointing to key and key_index_value we added
    xor rcx, rcx
    mov cl, byte[r15+key_index_bucket.entry_count] ; rax = entry count
    mov rax, key_index_entry_size
    mul rcx      ; rax = relptr in key_index_bucket.entries
    add rax, 1   ; rax = relptr in key_index_bucket to entry
    add rax, r15 ; rax = key_index_entry*

    mov rdi, qword[rbp-48] ; relptr to our stuff
    mov rsi, rdi
    add rsi, 6
    mov dword[rax+key_index_entry.key_relptr], esi
    mov dword[rbp-80], esi ; For .make_frame
    mov dword[rax+key_index_entry.value_relptr], edi

    inc byte[r15+key_index_bucket.entry_count] ; Increment bucket entry count

  .make_frame:
  ;; Come up with a unique id
  mov rdi, r12
  call _kv_stack_mkid
  mov qword[rbp-48], rax ; new id

  ;; Insert a new frame, referencing our key in our key_index_data with a relptr
  mov rdi, qword[r12+kv_stack.frames]
  mov rsi, frame_size
  call byte_buffer_extend
  mov rdi, qword[rbp-48]
  mov esi, dword[rbp-80]
  mov dword[rax+frame.id], edi
  mov dword[rax+frame.key_relptr], esi
  mov qword[rax+frame.value], r14

  ;; If we have ~>25% stale key_index_data bytes, compact key_index_data
  mov rdi, qword[r12+kv_stack.key_index_data]
  call byte_buffer_get_data_length
  shr rax, 2 ; / 4
  mov rdi, qword[r12+kv_stack.stale_key_index_bytes]
  cmp rdi, rax
  jl .no_compact_key_index_data
  mov rdi, r12
  call _kv_stack_compact_key_index_data ; TODO implement, is currently stub
  .no_compact_key_index_data:

  ;; If we have ~>25% stale frame bytes, compact frames
  mov rdi, qword[r12+kv_stack.frames]
  call byte_buffer_get_data_length
  shr rax, 2 ; / 4
  mov rdi, qword[r12+kv_stack.stale_frame_bytes]
  cmp rdi, rax
  jl .no_compact_frames
  mov rdi, r12
  call _kv_stack_compact_frames ; TODO implement, is currently stub
  .no_compact_frames:

  add rsp, 40
  pop rbx
  pop r15
  pop r14
  pop r13
  pop r12
  pop rbp
  ret

;; TODO
kv_stack_2_pop:
  ret

;; TODO
kv_stack_2_rm_by_id:
  ret

;; TODO
kv_stack_2_pop_by_key:
  ret

;; (kv_stack*) -> frame*
kv_stack_2_top:
  push r12
  push r13
  push r14

  ;; We can assume the top frame stored is not dead. See notes at the top of this file as to why.

  mov r12, qword[rdi+kv_stack.frames] ; frames byte_buffer*

  mov rdi, r12
  call byte_buffer_get_data_length
  mov r13, rax
  sub r13, frame_size ; rax = relptr to top frame

  ;; Error if there is no top frame (r13 < 0)
  cmp r13, 0
  jge .top_frame_exists

  mov rdi, no_top_err
  mov rsi, no_top_err_len
  call error_exit

  .top_frame_exists:

  mov rdi, r12
  call byte_buffer_get_buf
  add rax, r13 ; rax = frame*

  pop r14
  pop r13
  pop r12
  ret

;; TODO
;; -> frame*
kv_stack_2_top_with_key:
  ret

;; TODO
kv_stack_2_value_by_key:
  ret

;; TODO
kv_stack_2_value_by_id:
  ret

;; TODO
kv_stack_2_top_value:
  ret

;; (kv_stack*)
kv_stack_2_bindump_buffers:
  push r12
  push r13
  push r14

  mov r12, rdi ; kv_stack*

  ;; Frames

  mov rdi, frames_str
  mov rsi, frames_str_len
  mov rdx, 2
  call write

  mov rdi, qword[r12+kv_stack.frames]
  mov rsi, 2
  mov rdx, 16
  call byte_buffer_bindump_buffer

  ;; Buckets

  mov rdi, buckets_str
  mov rsi, buckets_str_len
  mov rdx, 2
  call write

  mov rax, qword[r12+kv_stack.key_index_bucket_count]
  mov rcx, key_index_bucket_size
  mul rcx
  mov rsi, rax
  mov rdi, qword[r12+kv_stack.key_index_buckets]
  mov rdx, 2
  mov rcx, 16
  call bindump

  ;; Key index data
  mov rdi, kid_str
  mov rsi, kid_str_len
  mov rdx, 2
  call write

  mov rdi, qword[r12+kv_stack.key_index_data]
  mov rsi, 2
  mov rdx, 16
  call byte_buffer_bindump_buffer

  pop r14
  pop r13
  pop r12
  ret

;; (kv_stack*)
_kv_stack_mkid:
  push r12

  mov r12, rdi

  ;; If there are no frames, return 1
  mov rdi, qword[r12+kv_stack.frames]
  call byte_buffer_get_data_length
  mov rdi, rax
  mov rax, 1
  cmp rdi, 0
  je .epilogue

  ;; Otherwise, our new id is the highest frame +1
  mov rdi, r12
  call kv_stack_2_top
  xor rdi, rdi
  mov edi, dword[rax+frame.id]
  inc edi

  mov rax, rdi

  .epilogue:
  pop r12
  ret

;; TODO
;; (kv_stack*)
_kv_stack_rehash_key_index:
  ret

;; TODO: this shares some code with barray_equalp in barray.asm. We should probably factor
;; out a 'memcmp'.
;; (barray* a, key* b) -> 1 if match, 0 if not
_kv_stack_compare_barray_to_key:
  mov r8, qword[rdi] ; length of barray
  xor r9, r9
  mov r9w, word[rsi] ; length of key

  ;; Default return of 0
  mov rax, 0

  ;; Compare lengths
  cmp r8, r9
  jne .epilogue

  ;; Move past lengths
  add rdi, 8
  add rsi, 2

  ;; Compare bulk in qword chunks
  mov rcx, r8
  shr rcx, 3 ; rcx = number of 8 byte blocks
  and r8, 7  ; remaining 0-7 bytes

  .qword_loop:
    test rcx, rcx
    jz .qword_loop_break
    mov rdx, qword[rsi]
    cmp rdx, qword[rdi]
    jne .epilogue
    add rsi, 8
    add rdi, 8
    dec rcx
    jmp .qword_loop
  .qword_loop_break:

  ;; Compare tail bytes byte-by-byte (unrolled loop)
  %rep 7
    test r8, r8
    jz .byte_loop_break
    mov cl, byte[rdi]
    cmp byte[rsi], cl
    jne .epilogue
    inc rdi
    inc rsi
    dec r8
  %endrep

  .byte_loop_break:

  ;; If we ran out the loop - then we found no differences. result is 1.
  mov rax, 1

  .epilogue:
  ret

;; (kv_stack*, key_index_bucket*, barray* key) -> key_index_entry*
;;
;; Returns NULL/0 if it doesn't exist
_kv_stack_scan_bucket_for_key:
  push r12
  push r13
  push r14
  push r15
  push rbx

  mov r12, qword[rdi+kv_stack.key_index_data] ; key_index_data byte_buffer*
  mov r13, rsi ; key_index_bucket*
  mov r14, rdx ; barray* key
  xor r15, r15
  mov r15b, byte[r13+key_index_bucket.entry_count]
  add r13, 1 ; move past entry_count

  mov rdi, r12
  call byte_buffer_get_buf
  mov r12, rax ; key_index_data*

  .scan_loop:
    test r15, r15
    jz .scan_loop_break

    ; r13 = key_index_entry*
    ;; Get key*
    mov rsi, r12
    xor r8, r8
    mov r8d, dword[r13+key_index_entry.key_relptr]
    add rsi, r8

    ;; Compare key* to barray*
    mov rdi, r14
    call _kv_stack_compare_barray_to_key
    mov rcx, rax

    ;; If match, return r13
    mov rax, r13
    cmp rcx, 1
    je .epilogue

    add r13, key_index_entry_size
    dec r15
    jmp .scan_loop
  .scan_loop_break:

  mov rax, 0 ; not found if we get here

  .epilogue:
  pop rbx
  pop r15
  pop r14
  pop r13
  pop r12
  ret

;; TODO
;; (kv_stack*)
_kv_stack_compact_key_index_data:
  ret

;; TODO
;; (kv_stack*)
_kv_stack_compact_frames:
  ret

%define FNV_OFFSET 14695981039346656037
%define FNV_PRIME 1099511628211

;; (kv_stack*, bucket_count, barray* key) -> bucket*
_kv_stack_key_index_bucket:
  dec rsi ; we need bucket_count-1 for fake-modulo masking
  mov r10, rdx

  mov rax, FNV_OFFSET
  mov rcx, FNV_PRIME

  mov r8, qword[r10]  ; barray len
  add r10, 8          ; move past len

  .loop:
    test r8, r8
    jz .loop_break

    xor al, byte[r10]  ; ^= byte
    mul rcx            ; *= FNV_PRIME

    inc r10
    dec r8
    jmp .loop
  .loop_break:

  and rax, rsi       ; %= bucket_count - rax = bucket index

  mov r9, key_index_bucket_size
  mul r9             ; rax = relptr to this bucket in buckets
  add rax, qword[rdi+kv_stack.key_index_buckets]
  ret

;; TODO compact key index data when >= 25% waste
;;   * NOTE: key relptrs exist in regular frames too, so make sure we repoint both the frames and
;;     the index relptrs upon compaction.
;; TODO compact frames whin >= 25% waste

