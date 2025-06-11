;; Hashmap designed for okish inserts and very fast reads. Keys are barrays, values are u64.
;;
;; * Hashmap values are fixed 8-byte values. If you need something bigger, use a pointer here.
;; * Buckets have a fixed size. If we exceed the size of a bucket, we re-hash. Thus, rehashing
;;   is going to happen sometimes on insert (but will otherwise be fast)
;; * Inserts will be fast if you don't need to rehash, so if you know your bounds you might
;;   want to set a larger starting bucket count.
;;
;;
;; struct hashmap {
;;   u64 bucket_count;
;;   bucket* buckets;   // malloc'd
;;   byte_buffer* keys; // byte buffer = dynamically growing
;; }
;;
;; struct bucket {
;;   u8    value_count;
;;   value values[HASHMAP_BUCKET_SIZE]; // flat
;; }
;;
;; struct value {
;;   u32 key_buffer_rel_ptr
;;   u64 value
;; }


;; TODO
;;
;; Right now on removal, we don't have a nice way to remove keys from the keys buffer.
;; One solution would be to track how many 'dead' keys we have in relation to 'alive' keys,
;; and trigger an expensive cleanup every time we hit > 50% wasted space.
;;
;; Cleanup would need to involve repointing all relptrs, so it would be pricey. We would probably
;; just run through all buckets and create a new keys byte buffer to replace the old.

global hashmap_new
global hashmap_get
global hashmap_set
global hashmap_rm
global hashmap_free
global hashmap_rehash

extern malloc
extern free

extern error_exit
extern barray_equalp

extern byte_buffer_new
extern byte_buffer_free
extern byte_buffer_get_buf
extern byte_buffer_get_data_length
extern byte_buffer_push_barray

extern print
extern write_as_base
extern write_char

;; Macro to round a number to the nearest power of 2
;%macro round_pow_2 1
;  %assign V %1
;  %assign V V - 1
;  %assign V V | V >> 1
;  %assign V V | V >> 2
;  %assign V V | V >> 4
;  %assign V V | V >> 8
;  %assign V V | V >> 16
;  %assign V V + 1
;%endmacro
;
;%macro log2_pow2 2  ; Takes power-of-2 value and result variable name
;  %assign %2 0
;  %assign _temp %1
;  %if _temp > 1
;    %rep 32  ; enough iterations for 32-bit values
;      %if _temp > 1
;        %assign _temp _temp >> 1
;        %assign %2 %2 + 1
;      %endif
;    %endrep
;  %endif
;%endmacro

%define HASHMAP_MAX_VALUES_PER_BUCKET 8
%define HASHMAP_VALUE_SIZE (4 + 8)
%define HASHMAP_BUCKET_SIZE (1 + (HASHMAP_VALUE_SIZE * HASHMAP_MAX_VALUES_PER_BUCKET))
;round_pow_2 HASHMAP_BUCKET_SIZE_MIN
;%define HASHMAP_BUCKET_SIZE (V)
%define HASHMAP_STRUCT_SIZE 24

%define HASHMAP_BUCKETS_OFFSET 8
%define HASHMAP_KEYS_OFFSET 16

%define HASHMAP_VALUE_VALUE_OFFSET 4

;log2_pow2 HASHMAP_BUCKET_SIZE, HASHMAP_BUCKET_SHIFT

section .rodata

not_pow2_err: db "ERROR: Non-power-of-2 bucket count requested for hashmap_new. It must be a power of 2.",10
not_pow2_err_len: equ $ - not_pow2_err

section .text

;; (starting_bucket_count) -> hashmap*
;;
;; starting_bucket_count must be a power of 2
hashmap_new:
  push r12
  push r13
  push r14

  mov r12, rdi ; r12 = starting bucket count

  ;; Error if starting bucket count not a power of 2
  mov rax, r12
  dec rax
  and rax, r12
  jz .is_pow2

  mov rdi, not_pow2_err
  mov rsi, not_pow2_err_len
  call error_exit

  .is_pow2:

  ;; Allocate our struct
  mov rdi, HASHMAP_STRUCT_SIZE
  call malloc
  mov r13, rax ; r13 = struct hashmap*

  ;; TODO error if malloc fails

  ;; Bucket count
  mov qword[r13], r12

  ;; Keys buffer
  call byte_buffer_new
  mov qword[r13+16], rax

  ;; Buckets allocation
  mov rax, HASHMAP_BUCKET_SIZE
  mul r12
  mov rdi, rax
  mov r14, rdi
  call malloc
  mov qword[r13+8], rax

  ;; TODO error if malloc fails

  ;; Zero out buckets allocation
  mov rdi, rax ; dest
  mov rcx, r14
  shr rcx, 3 ; / 8
  xor rax, rax
  rep stosq

  mov rax, r13 ; return hashmap struct pointer
  pop r14
  pop r13
  pop r12
  ret

;; (hashmap*)
hashmap_free:
  push r12
  push r13
  push r14

  mov r12, rdi ; hashmap*

  test r12, r12
  jz .epilogue

  ;; NOTE: We do this exactly in the opposite order as hashmap_new because it's more friendly
  ;; to our allocator. Make sure we maintain this property for performance reasons.

  mov rdi, qword[r12+8]
  call free

  mov rdi, qword[r12+16]
  call byte_buffer_free

  mov rdi, r12
  call free

  .epilogue:
  pop r14
  pop r13
  pop r12
  ret

;; (hashmap*, barray* key) -> pointer to value
;;
;; Returns NULL/0 if the key doesn't exist.
;;
;; You may mutate the value with this pointer.
;;
;; The returned pointer is invalid after any insert, as insertions may trigger a rehash.
hashmap_get:
  push r12
  push r13
  push r14
  push r15
  push rbx

  mov r12, rdi ; hashmap*
  mov r13, rsi ; barray* key

  ;; Find the bucket
  mov rdi, r13
  mov rsi, qword[r12]
  call _hashmap_bucket
  mov rsi, HASHMAP_BUCKET_SIZE
  mul rsi
  mov r15, qword[r12+HASHMAP_BUCKETS_OFFSET] ; rl5 = buckets*
  add r15, rax          ; r15 = bucket*

  ;; Grab keys buffer for our search
  mov rdi, qword[r12+HASHMAP_KEYS_OFFSET]
  call byte_buffer_get_buf
  mov rbx, rax

  ;; Iterate over the bucket, searching for our key
  mov r14b, byte[r15] ; r14b = value count
  inc r15             ; move past length
  .search_loop:
  test r14b, r14b
  jz .search_loop_break

  xor rdi, rdi
  mov edi, dword[r15] ; rdi = key buffer rel ptr
  add rdi, rbx        ; rdi = pointer to key barray
  mov rsi, r13
  call barray_equalp
  mov rdi, rax          ; rdi = our result
  lea rax, qword[r15+HASHMAP_VALUE_VALUE_OFFSET] ; rax = pointer to our value in case we return
  cmp rdi, 1
  je .epilogue

  add r15, HASHMAP_VALUE_SIZE
  dec r14b
  jmp .search_loop
  .search_loop_break:

  ;; Nothing found if we got here, return NULL,0
  mov rax, 0

  .epilogue:
  pop rbx
  pop r15
  pop r14
  pop r13
  pop r12
  ret

;; (hashmap*, barray* key)
;;
;; Does nothing if the key didn't exist
hashmap_rm:
  push rbp
  mov rbp, rsp
  push r12
  push r13
  push r14
  push r15
  push rbx
  sub rsp, 24

  mov r12, rdi ; hashmap*
  mov r13, rsi ; barray* key

  ;; Find the bucket
  mov rdi, r13
  mov rsi, qword[r12]
  call _hashmap_bucket
  mov rsi, HASHMAP_BUCKET_SIZE
  mul rsi
  mov r15, qword[r12+HASHMAP_BUCKETS_OFFSET] ; rl5 = buckets*
  add r15, rax          ; r15 = bucket*

  ;; Grab keys buffer for our search
  mov rdi, qword[r12+HASHMAP_KEYS_OFFSET]
  call byte_buffer_get_buf
  mov rbx, rax

  ;; Preserve bucket*
  mov qword[rbp-56], r15

  ;; Iterate over the bucket, searching for our key
  mov qword[rbp-48], 0 ; not shift mode
  mov r14b, byte[r15] ; r14b = value count
  inc r15             ; move past length
  .search_loop:
    test r14b, r14b
    jz .search_loop_break

    ; r15 = value*

    cmp qword[rbp-48], 1
    je .shiftmode

    xor rdi, rdi
    mov edi, dword[r15] ; rdi = key buffer rel ptr
    add rdi, rbx        ; rdi = pointer to key barray
    mov rsi, r13
    call barray_equalp
    cmp rax, 1
    jne .continue

    ;; We found the value struct to remove. Decrement the value count.
    mov rdi, qword[rbp-56]
    dec byte[rdi]

    ;; Start shifting instead of searching.
    mov qword[rbp-48], 1 ; Enable shift mode

    .shiftmode:

    ;; If the is the last one, do nothing.
    cmp r14b, 1
    je .continue

    ;; Shift the next value on top of us
    mov rdi, r15
    mov rsi, r15
    add rsi, HASHMAP_VALUE_SIZE
    mov rcx, HASHMAP_VALUE_SIZE
    rep movsb

    .continue:

    add r15, HASHMAP_VALUE_SIZE
    dec r14b
    jmp .search_loop
  .search_loop_break:

  add rsp, 24
  pop rbx
  pop r15
  pop r14
  pop r13
  pop r12
  pop rbp
  ret

;; (hashmap*, barray* key, u64 value)
;;
;; If the key already exists, we'll replace it and it's current value.
hashmap_set:
  push r12
  push r13
  push r14
  push r15
  push rbx

  mov r12, rdi ; hashmap*
  mov r13, rsi ; barray* key
  mov r14, rdx ; u64 value

  ;; Check with hashmap_get to see if it already exists. If it does, just update that and return
  call hashmap_get
  test rax, rax
  jz .need_to_insert

  mov qword[rax], r14
  jmp .epilogue

  .need_to_insert:

  ;; Get our bucket
  mov rdi, r13
  mov rsi, qword[r12]
  call _hashmap_bucket
  mov rsi, HASHMAP_BUCKET_SIZE
  mul rsi
  mov r15, qword[r12+HASHMAP_BUCKETS_OFFSET] ; rl5 = buckets*
  add r15, rax                               ; r15 = bucket*

  ;; If our bucket is full, we need to rehash to make room
  cmp byte[r15], HASHMAP_MAX_VALUES_PER_BUCKET
  jl .insert

  ;; Rehash
  mov rdi, r12 ; hashmap*
  call hashmap_rehash

  ;; Recurse to insert the value, because it's technically possible we might need multiple rehashes
  ;; We also need to restart our logic anyway because our backing data has changed completely.
  mov rdi, r12
  mov rsi, r13
  mov rdx, r14
  call hashmap_set
  jmp .epilogue

  .insert:
  ;; Add our key to the keys buffer, keeping track of it's relptr
  mov rdi, qword[r12+HASHMAP_KEYS_OFFSET]
  call byte_buffer_get_data_length
  mov rbx, rax ; rbx = key relptr

  mov rdi, qword[r12+HASHMAP_KEYS_OFFSET]
  mov rsi, r13
  call byte_buffer_push_barray

  ;; Add our key relptr and value to our bucket, incrementing the value count
  mov rax, HASHMAP_VALUE_SIZE
  mul byte[r15]                                  ; rax = value_count*value_size
  inc byte[r15]                                  ; increment value count
  inc r15                                        ; move past value count
  add r15, rax                                   ; move to our new value
  mov dword[r15], ebx                            ; write key relptr
  mov qword[r15+HASHMAP_VALUE_VALUE_OFFSET], r14 ; write value

  .epilogue:
  pop rbx
  pop r15
  pop r14
  pop r13
  pop r12
  ret

;; (hashmap*, new_buckets*, new_bucket_count)
;;
;; Returns 1 on success, 0 if we need more buckets for this
_hashmap_fill_new_buckets:
  push rbp
  mov rbp, rsp
  push r12
  push r13
  push r14
  push r15
  push rbx
  sub rsp, 24

  mov qword[rbp-48], rdi ; hashmap
  mov qword[rbp-56], rsi ; new_buckets*
  mov qword[rbp-64], rdx ; new_bucket_count
  mov r13, qword[rdi]    ; bucket_count

  mov rcx, qword[rdi+HASHMAP_BUCKETS_OFFSET]
  mov r14, rcx ; buckets*

  mov rdi, qword[rdi+HASHMAP_KEYS_OFFSET] ; keys buffer
  call byte_buffer_get_buf                ; get base address
  mov rbx, rax

  ;; Iterate over all of our old values
  .bucket_loop:
    test r13, r13
    jz .bucket_loop_break

    xor rax, rax
    mov al, byte[r14]
    mov r15, rax ; value count

    mov r12, r14
    inc r12 ; Move past value count - r12 = values*

    .value_loop:
      test r15, r15
      jz .value_loop_break

      ; r12 = value*

      ;; Hash it's key again
      xor rsi, rsi
      mov esi, dword[r12]
      mov rdi, rbx        ; keys*
      add rdi, rsi        ; our key barray
      mov rsi, qword[rbp-64]
      call _hashmap_bucket

      ;; Get our target bucket
      mov rsi, HASHMAP_BUCKET_SIZE
      mul rsi ; rax (bucket index) *= bucket size
      mov r9, qword[rbp-56]
      add r9, rax ; r9 = bucket*

      ;; If this key's bucket is full, return 0
      mov rax, 0
      cmp byte[r9], HASHMAP_MAX_VALUES_PER_BUCKET
      jge .epilogue

      ;; Add our key and value to correct target bucket
      xor rax, rax
      mov al, byte[r9] ; rax = value count
      mov rsi, HASHMAP_VALUE_SIZE
      mul rsi ; rax *= value size

      inc byte[r9] ; Increment length (we're adding one)
      inc r9       ; move past length
      add r9, rax  ; move to value
      mov r8d, dword[r12]
      mov dword[r9], r8d
      mov r8, qword[r12+HASHMAP_VALUE_VALUE_OFFSET]
      mov qword[r9+HASHMAP_VALUE_VALUE_OFFSET], r8

      add r12, HASHMAP_VALUE_SIZE
      dec r15
      jmp .value_loop
    .value_loop_break:

    add r14, HASHMAP_BUCKET_SIZE
    dec r13
    jmp .bucket_loop
  .bucket_loop_break:

  mov rax, 1 ; We succeeded if we got here
  .epilogue:
  add rsp, 24
  pop rbx
  pop r15
  pop r14
  pop r13
  pop r12
  pop rbp
  ret

;; (hashmap*)
;;
;; Increases bucket count and re-inserts everything.
hashmap_rehash:
  push rbp
  mov rbp, rsp
  push r12
  push r13
  push r14
  push r15
  push rbx
  sub rsp, 24

  mov r12, rdi ; hashmap*

  mov r13, qword[r12] ; bucket count
  mov r14, r13
  shl r14, 1          ; r14 = target bucket count - double starting value

  .go:

  ;; Make new buckets allocation of correct size for target bucket count
  mov rax, HASHMAP_BUCKET_SIZE
  mul r14
  mov rdi, rax
  mov rbx, rdi
  call malloc
  mov r15, rax ; r15 = target buckets allocation

  ;; TODO error if malloc fails

  ;; Zero out the new target buckets allocation
  mov rdi, r15 ; dest
  mov rcx, rbx
  shr rcx, 3 ; / 8
  xor rax, rax
  rep stosq

  ;; Try to fill our new buckets
  mov rdi, r12 ; hashmap*
  mov rsi, r15 ; new_buckets*
  mov rdx, r14 ; new_bucket_count
  call _hashmap_fill_new_buckets
  cmp rax, 1
  je .done

  ;; We failed - not enuff bukkits!

  ;; Free new buckets allocation
  mov rdi, r15
  call free

  ;; Try again with moar bukkit...
  shl r14, 1 ; * 2
  jmp .go

  .done:
  ;; Free old buckets allocation
  mov rdi, qword[r12+HASHMAP_BUCKETS_OFFSET]
  call free

  ;; Repoint hashmap to our new buckets allocation
  mov qword[r12+HASHMAP_BUCKETS_OFFSET], r15

  ;; Update our bucket count to the target count
  mov qword[r12], r14

  add rsp, 24
  pop rbx
  pop r15
  pop r14
  pop r13
  pop r12
  pop rbp
  ret

%define FNV_OFFSET 14695981039346656037
%define FNV_PRIME 1099511628211

;; (barray, bucket_count) -> u64
_hashmap_bucket:
  dec rsi ; we need bucket_count-1 for fake-modulo masking

  mov rax, FNV_OFFSET
  mov rcx, FNV_PRIME

  mov r8, qword[rdi] ; barray len
  add rdi, 8          ; move past len

  .loop:
  test r8, r8
  jz .loop_break

  xor al, byte[rdi]  ; ^= byte
  mul rcx            ; *= FNV_PRIME

  inc rdi
  dec r8
  jmp .loop
  .loop_break:

  and rax, rsi       ; %= bucket_count
  ret
