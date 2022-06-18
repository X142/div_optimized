; Functions in this code is for debug, so
; not only callee-saved-register 
; but also caller-saved-register may be saved against ABI.
;
; callee-saved-registers in UNIX: rsp, rbp, rbx, r12-r15

global G_cerr_LF
global G_cerr_string
global G_cerr_uint32_hex
global G_cerr_uint64_hex
global G_cerr_uint128_hex
global G_cerr_uint64_dec

global G_set_dec_str_to_buf
global G_cout_2
global G_cout_num
global strlen
global str_to_num

bits 64 ; 64bit mode
; In 64bit mode, rip-relative-addressing is supported 
; for all instructions that uses ModR/M by setting
; Mod = 00b, R/M = 101b : [rip + disp32]
default rel ; use rip-relative-addressing by default

; ================================================================
%define sys_write 0x1

; ================================================================
section .text
G_cerr:
; ----------------------------------------------------------------
; 標準エラー出力へ文字列を表示する
; 
; <<< ARGS
; rsi: 表示する文字列が格納されたアドレス 
; rdx: 表示する文字列の長さ
; >>> RETURN
; -
; --- DESTROY
; -
	push rax ; for debug
	push r11 ; for debug ; Note: syscall destroys rcx, r11
	push rcx ; for debug ; Note: syscall destroys rcx, r11
	push rdi ; for debug

	push rbp
	mov rbp, rsp

	mov rax, sys_write
	mov rdi, 2 ; fd = 2
	syscall

	mov rsp, rbp
	pop rbp

	pop rdi
	pop rcx
	pop r11
	pop rax

	ret

G_cerr_LF:
; ----------------------------------------------------------------
; 改行 (0xa) を表示する
; 
; <<< ARGS
; -
; >>> RETURN
; -
; --- DESTROY
; -
	push rdx ; for debug
	push rsi ; for debug

	push rbp
	mov rbp, rsp

	mov rsi, LF
	mov rdx, 1
	call G_cerr

	mov rsp, rbp
	pop rbp

	pop rsi
	pop rdx

	ret

G_cerr_uint32_hex:
; ----------------------------------------------------------------
; 符号なし 32bit 値を改行 (0xa) 付きで表示する
; 
; <<< ARGS
; rdi: 表示する 32bit 値
; >>> RETURN
; -
; --- DESTROY
; -
	push rax ; for debug
	push rdx ; for debug
	push rsi ; for debug
	push rdi ; for debug

	push rbp
	mov rbp, rsp

	call L_uint32_to_HexString
	mov [L_buf_HexString], rax

	lea rsi, [L_buf_HexString]
	mov edx, 8
	call G_cerr

	call G_cerr_LF

	mov rsp, rbp
	pop rbp

	pop rdi
	pop rsi
	pop rdx
	pop rax

	ret

G_cerr_uint64_hex:
; ----------------------------------------------------------------
; 符号なし 64bit 値を改行 (0xa) 付きで表示する
; 
; <<< ARGS
; rdi: 表示する 64bit 値
; >>> RETURN
; -
; --- DESTROY
; -
	push rax ; for debug
	push rdx ; for debug
	push rsi ; for debug
	push rdi ; for debug

	push rbp
	mov rbp, rsp

	call L_uint32_to_HexString
	mov [L_buf_HexString + 8 + 1], rax
	shr rdi, 32

	call L_uint32_to_HexString
	mov [L_buf_HexString], rax

	lea rsi, [L_buf_HexString]
	mov edx, 8 + 1 + 8 + 1
	call G_cerr

	call G_cerr_LF

	mov rsp, rbp
	pop rbp

	pop rdi
	pop rsi
	pop rdx
	pop rax

	ret

G_cerr_uint128_hex:
; ----------------------------------------------------------------
; 符号なし 128bit 値を改行 (0xa) 付きで表示する
; （注意）スタックの 16 bytes aligned を要求する
; 
; <<< ARGS
; xmm0: 表示する 128bit 値
; >>> RETURN
; -
; --- DESTROY
; -
	push rax ; for debug
	sub rsp, 8 ; for 16 bytes aligned
	sub rsp, 16
	movdqa [rsp], xmm0 ; for debug
	push rdx ; for debug
	push rsi ; for debug
	push rdi ; for debug

	push rbp
	mov rbp, rsp

	movd edi, xmm0
	call L_uint32_to_HexString
	mov [L_buf_HexString + 8 + 1 + 8 + 1 + 8 + 1], rax
	psrldq xmm0, 4

	movd edi, xmm0
	call L_uint32_to_HexString
	mov [L_buf_HexString + 8 + 1 + 8 + 1], rax
	psrldq xmm0, 4

	movd edi, xmm0
	call L_uint32_to_HexString
	mov [L_buf_HexString + 8 + 1], rax
	psrldq xmm0, 4

	movd edi, xmm0
	call L_uint32_to_HexString
	mov [L_buf_HexString], rax
	; psrldq xmm0, 4

	lea rsi, [L_buf_HexString]
	mov edx, 8 + 1 + 8 + 1 + 8 + 1 + 8 + 1
	call G_cerr

	call G_cerr_LF

	mov rsp, rbp
	pop rbp

	pop rdi
	pop rsi
	pop rdx
	movdqa xmm0, [rsp]
	add rsp, 16
	add rsp, 8
	pop rax

	ret

L_uint32_to_HexString:
; ----------------------------------------------------------------
; 符号なし 32bit 値を 64bit の 16 進数文字列へ変換する
; 
; <<< ARGS
; rdi: 変換する 32bit 値
; >>> RETURN
; rax: 変換された 64bit の 16 進数文字列
; --- DESTROY
; -
	push r8 ; for debug
	push rbx

	push rbp
	mov rbp, rsp

	mov rax, 0x3030303030303030

	r0_uint32_to_HexString:
		mov r8d, edi
		and r8d, 0xf << 0
		cmp r8d, 0xa << 0
		jc r1_uint32_to_HexString
		add r8d, 0x61 - (0x30 + 10) << 0
	r1_uint32_to_HexString:
		shl r8, (64 - 8*1) - 4*0 ; r8[4*0] -> r8[64-8*1]
		add rax, r8

		mov r8d, edi
		and r8d, 0xf << 4
		cmp r8d, 0xa << 4
		jc r2_uint32_to_HexString
		add r8d, (0x61 - (0x30 + 10)) << 4
	r2_uint32_to_HexString:
		shl r8, 64 - 8*2 - 4*1 ; r8[4*1] -> r8[64-8*2]
		add rax, r8

		mov r8d, edi
		and r8d, 0xf << 8
		cmp r8d, 0xa << 8
		jc r3_uint32_to_HexString
		add r8d, (0x61 - (0x30 + 10)) << 8
	r3_uint32_to_HexString:
		shl r8, (64 - 8*3) - 4*2 ; r8[4*2] -> r8[64-8*3]
		add rax, r8

		mov r8d, edi
		and r8d, 0xf << 12
		cmp r8d, 0xa << 12
		jc r4_uint32_to_HexString
		add r8d, (0x61 - (0x30 + 10)) << 12
	r4_uint32_to_HexString:
		shl r8, (64 - 8*4) - 4*3 ; r8[4*3] -> r8[64-8*4]
		add rax, r8

		mov r8d, edi
		and r8d, 0xf << 16
		cmp r8d, 0xa << 16
		jc r5_uint32_to_HexString
		add r8d, (0x61 - (0x30 + 10)) << 16
	r5_uint32_to_HexString:
		shl r8d, (64 - 8*5) - 4*4 ; !!r8d ; r8[4*4] -> r8[64-8*5]
		add rax, r8

		mov r8d, edi
		and r8d, 0xf << 20
		cmp r8d, 0xa << 20
		jc r6_uint32_to_HexString
		add r8d, (0x61 - (0x30 + 10)) << 20
	r6_uint32_to_HexString:
		shr r8d, 4*5 - (64 - 8*6) ; r8[4*5] -> r8[64-8*6]
		add rax, r8

		mov r8d, edi
		and r8d, 0xf << 24
		cmp r8d, 0xa << 24
		jc r7_uint32_to_HexString
		add r8d, (0x61 - (0x30 + 10)) << 24
	r7_uint32_to_HexString:
		shr r8d, 4*6 - (64 - 8*7) ; r8[4*6] -> r8[64-8*7]
		add rax, r8

		mov r8d, edi
		and r8d, 0xf << 28
		cmp r8d, 0xa << 28
		jc r__uint32_to_HexString
		mov rbx, (0x61 - (0x30 + 10)) << 28
		add r8, rbx
	r__uint32_to_HexString:
		shr r8, 4*7 - (64 - 8*8) ; !!r8 ; r8[4*7] -> r8[64-8*8]
		add rax, r8

	mov rsp, rbp
	pop rbp

	pop rbx
	pop r8

	ret

G_cerr_string:
; ----------------------------------------------------------------
; null-teminated-string を表示する
; 文字列の長さの上限 : 8bytes
; 
; <<< ARGS
; rsi : 表示する文字列が格納されたアドレス
; >>> RETURN
; -
; --- DESTROY
; -
	push rax ; for debug
	push rdx ; for debug
	push rsi ; for debug
	push rdi ; for debug

	push rbp
	mov rbp, rsp

	mov rdi, rsi
	push rcx ; for debug
	call L_strlen
	pop rcx

	mov rdx, rax ; length
	call G_cerr

	mov rsp, rbp
	pop rbp

	pop rdi
	pop rsi
	pop rdx
	pop rax

	ret

L_strlen:
; ----------------------------------------------------------------
; null-teminated-string の長さ (最大 64bit 最大値) を取得する
; 
; <<< ARGS
; rdi : 文字列が格納されたアドレス
; >>> RETURN
; rax : 文字列の長さ
; --- DESTROY
; rcx
	; memo : 
	; The direction flag DF in the %rFLAGS register must be clear 
	; (set to “forward” direction) on function entry and return. 
	; Other user flags have no specified role in the standard calling sequence 
	; and are not preserved across calls.
	cld

	push rbp
	mov rbp, rsp

	xor eax, eax ; compare char = 0x0 (null)
	mov rcx, 0xffffffffffffffff ; max length = 8bytes
	; while (rcx != 0 || ZF != 1)
	; {
	; 	if (*rdi == rax)
	;	{
	; 		ZF = 1;
	; 	}
	; 	++rdi;
	; 	--rcx;
	; }
	repne scasb

	not rcx
	mov rax, rcx

	mov rsp, rbp
	pop rbp

	ret

G_cerr_uint64_dec:
; ----------------------------------------------------------------
; 符号なし 64bit 値を 改行 (0xa) 付き 10 進数で表示する
; 
; <<< ARGS
; rdi : 64bit 値
; >>> RETURN
; -
; --- DESTROY
; -
	push rax
	push rdx
	push rsi

	push rbp
	mov rbp, rsp

	mov rsi, L_buf_DecString
	call L_uint64_to_DecString

	mov rsi, rax
	call G_cerr

	call G_cerr_LF

	mov rsp, rbp
	pop rbp

	pop rsi
	pop rdx
	pop rax

	ret

L_uint64_to_DecString:
; ----------------------------------------------------------------
; 符号なし 64bit 値を 10 進数文字列に変換する
; 
; <<< ARGS
; rdi : 64bit 値
; rsi : 変換された文字列を格納する 20bytes バッファのアドレス
; 	  : 20bytes の 20 は 64bit 値の 10 進数における最大桁数
; >>> RETURN
; rax : 変換された文字列の先頭アドレス
; rdx : 変換された文字列の長さ
; --- DESTROY
; -
	push r9 ; for debug
	push r8 ; for debug
	push rcx ; for debug
	push rsi ; for debug
	push rdi ; for debug
	push rbx

	push rbp
	mov rbp, rsp

    mov rax, rdi
	mov edi, 10
    add rsi, 20
	xor ecx, ecx
    xor r8d, r8d
	mov r9, rsi
	mov rbx, 0x3030303030303030

    L_loop_uint64_to_DecString:
        add ecx, 8

		shl r8, 8
		xor edx, edx
        div rdi
		add r8, rdx

		; rax = 0 ?
		or rax, rax
		je L_store_uint64_to_DecString

		; ecx % 64 = 0 ?
		test ecx, 63
        jne L_loop_uint64_to_DecString

		or r8, rbx
		sub rsi, 8
		mov [rsi], r8
		jmp L_loop_uint64_to_DecString

	L_store_uint64_to_DecString:
		neg ecx
		add ecx, 64
		and ecx, 63

		; loop3 ?
		cmp ecx, 64*2 + 8
		jnc .loop3_uint64_to_DecString

			shl r8, cl

			or r8, rbx
			sub rsi, 8
			mov [rsi], r8

			jmp L_end_uint64_to_DecString

		.loop3_uint64_to_DecString:
			shl r8, cl

			or r8d, 0x30303030
			sub rsi, 4
			mov [rsi], r8d

	L_end_uint64_to_DecString:
	shr ecx, 3
	add rsi, rcx

	sub r9d, esi

	mov rax, rsi
	mov edx, r9d

	mov rsp, rbp
	pop rbp

	pop rbx
	pop rdi
	pop rsi
	pop rcx
	pop r8
	pop r9

	ret

G_DecString_to_uint64:
; ----------------------------------------------------------------
; null terminated 数字文字列 (最大 20bytes) を 64bit 値へ変換する
; 
; <<< ARGS
; rdi : 数字文字列のアドレス
; >>> RETURN
; rax : 64bit 値
; --- DESTROY
; -
	cld ; clear DF

	push r9
	push r8
	push rcx
	push rdx
	push rsi
	push rdi

	push rbp
	mov rbp, rsp

	mov rsi, rdi ; rdi -> rsi

	mov ecx, 20 + 1
	xor eax, eax ; compare char = 0x0 (null)
	; while (rcx != 0 || ZF != 1)
	; {
	; 	if (*rdi == rax)
	;	{
	; 		ZF = 1;
	; 	}
	; 	++rdi;
	; 	--rcx;
	; }
	repne scasb

	; rcx = null を除く文字数
	not rcx
	add rcx, 20 + 1

	mov r8d, 10

	; ecx % 8 先に処理を行い ecx を 8n に
	.ecx_bit3_DecString_to_uint64:
		test ecx, 7
		je .ecx_aligned_8

	.ecx_bit2_DecString_to_uint64:
		test ecx, 4
		je .ecx_bit1_DecString_to_uint64

		mov edi, [rsi]
		and edi, 0x0f0f0f0f

		; mul r8d
		mov edx, 0xff
		and edx, edi
		add eax, edx
		shr edi, 8

		%rep 2
		mul r8d
		mov edx, 0xff
		and edx, edi
		add eax, edx
		shr edi, 8
		%endrep

		mul r8d
		mov edx, 0xff
		and edx, edi
		add eax, edx
		; shr edi, 8

		add rsi, 4

	.ecx_bit1_DecString_to_uint64:
		test ecx, 2
		je .ecx_bit0_DecString_to_uint64

		mov di, [rsi]
		and edi, 0x0f0f

		mul r8d
		mov edx, 0xff
		and edx, edi
		add eax, edx
		shr edi, 8

		mul r8d
		mov edx, 0xff
		and edx, edi
		add eax, edx
		; shr edi, 8

		add rsi, 2

	.ecx_bit0_DecString_to_uint64:
		test ecx, 1
		je .ecx_aligned_8

		mov dil, [rsi]
		and edi, 0x0f

		mul r8d
		mov edx, 0xff
		and edx, edi
		add eax, edx
		; shr edi, 8

		add rsi, 1

	.ecx_aligned_8:
	and ecx, ~7
	je L_end_DecString_to_uint64
	mov r9, 0x0f0f0f0f0f0f0f0f

	L_loop_DecString_to_uint64:
		mov rdi, [rsi]
		and rdi, r9

		%rep 7
		mul r8
		mov edx, 0xff
		and edx, edi
		add rax, rdx
		shr rdi, 8
		%endrep

		mul r8
		mov edx, 0xff
		and edx, edi
		add rax, rdx
		; shr rdi, 8

		add rsi, 8

		sub ecx, 8

		jne L_loop_DecString_to_uint64

	L_end_DecString_to_uint64:
	mov rsp, rbp
	pop rbp

	pop rdi
	pop rsi
	pop rdx
	pop rcx
	pop r8
	pop r9

	ret

; ================================================================
section .data
align 4
LF:
	DB 0xa

align 64
L_buf_HexString:
	DB "00000000 00000000 00000000 00000000 "

L_buf_DecString:
	DB "00000000000000000000"
