; Functions in this code is for debug, so
; not only callee-saved-register 
; but also caller-saved-register may be saved against ABI.
;
; callee-saved-registers in UNIX: rsp, rbp, rbx, r12-r15

global G_cerr_LF
global G_cerr_uint32_hex
global G_cerr_uint64_hex
global G_cerr_uint128_hex
global G_cerr_string

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
	push r11 ; for debug ; Note: syscall destroys rcx, r11
	push rax ; for debug
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
	pop rax
	pop r11

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
	sub rsp, 8 ; for 16 bytes aligned
	sub rsp, 16
	movdqa [rsp], xmm0 ; for debug
	push rax ; for debug
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
	pop rax
	movdqa xmm0, [rsp]
	add rsp, 16
	add rsp, 8

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
; null-teminated-string の長さを取得する
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

; ================================================================
section .data
align 4
LF:
	DB 0xa

align 64
L_buf_HexString:
	DB '00000000 00000000 00000000 00000000 '



















L_div_by_10_64:
; 64bit ÷ 64bit 除算を実行する
; 
; <<<ARGS
; rdi : 被除数
; >>>RETURN
; rax : 商
; rdx : 余り
; --- DESTROY
; rsi, rdx, rcx, rax
    push rbp
    mov rbp, rsp

    ; rcx = p = 10
    mov esi, 10

    ; rdx = C/p = [(2^64)/10] + 1
    mov rdx, 0x199999999999999a

    ; rdx = q' = (n*(C/p))[127:64]
    mov rax, rdi
    mul rdx
    mov rcx, rdx

    ; rax = q'*p
    mov rax, rcx
    mul rsi

    sub rdi, rax ; rdi = r' = n - q'*p
    jnc .end_div_by_10_64 ; r' < 0 ?

	; q = q' - 1
    sub rcx, 1
	; r = r' + p
    add rax, rsi

    .end_div_by_10_64:
        mov rax, rcx
        mov rdx, rdi

    mov rsp, rbp
    pop rbp

	ret


;;; 以下更新中

; ----------------------------------------------------------------
; G_set_dec_str_to_buf
; edi で渡された値を、10進数の文字列に変換する
; 32 bit 値までの対応

; <<< IN
; edi : 10進数の文字列に変換したい値
; >>> OUT
; rax : 変換された文字列がストアされた先頭アドレス
;   文字列の先頭に文字数が 32bit 値で格納されている
G_set_dec_str_to_buf:
	push	rdi ; for debug
	push	rsi ; for debug
	push	rdx ; for debug
	push	rcx ; for debug
	push	r8  ; for debug

	mov eax, edi ; 被除数
	mov edi, 10 ; 除数
	mov rsi, L_buf_dec_str + 4 + 10 ; 4:文字数, 10:32bit値の最大桁数
	xor edx, edx
	xor ecx, ecx ; 文字数カウンタ
	xor r8d, r8d ; 10 による剰余

	L_loop_1:
		div edi

		shl r8d, 8
		add r8d, edx

		xor edx, edx
		add ecx, 1

		; ecx が 4 の倍数
		; r8d をストア
		test ecx, 3
		je L_loop_1_load

		; ecx が 4 の倍数でない かつ eax == 0 ?
		; ループ継続 または r8d,文字数をストアして終了
		or eax, eax
		je L_loop_1_shl_load

		jmp L_loop_1

	; （例）
	; 	r8d に 0321 と入ってたら、
	; 	little endian に注意して、1bit 左シフトして、
	; 	3210 にしてロードしなければならない
	; これは、4 - (ecx % 4) bit 左シフトするということ
	L_loop_1_shl_load:
		mov edi, ecx ; 文字数 ecx を保存しておく

		; ecx = edx = 4 - (ecx % 4)
		and ecx, 3
		neg ecx
		add ecx, 4
		; 文字列の先頭のアドレス = rsi + (4 - ecx % 4)
		; 	を求めるときに必要になるので、edx に保存しておく
		mov edx, ecx

		shl ecx, 3 ; 8 倍して、その分 r8d を左シフト
		shl r8d, cl

		mov ecx, edi
	L_loop_1_load:
		sub rsi, 4
		or r8d, 0x30303030
		mov [rsi], r8d
		xor r8d, r8d

		or eax, eax
		jne L_loop_1

	add rsi, rdx ; rsi に、保存しておいた edx を加算すると、丁度文字列が始まる 先頭アドレスになる
	sub rsi, 4 ; 先頭に文字数 ecx を入れるので、4 減算する
	mov [rsi], ecx
	mov rax, rsi
	
	pop	r8
	pop	rcx
	pop	rdx
	pop	rsi
	pop	rdi

	ret
	
; ================================================================
section .data
; 32 bit 値は最大で 10 文字
; 文字数をストアするため、さらに 4 bytes 確保している
L_buf_dec_str:
	db "00003412341234"

; ================================================================
section .text
; ----------------------------------------------------------------
; G_cout_2
; 文字列を fd2 に表示する
; <<< IN
; rsi : 文字列が格納されているアドレス
;   先頭に 4 byte 値で文字列長が格納されている
G_cout_2:
	push	rdi ; for debug
	push	rdx ; for debug
	push	rcx ; for debug
	push	rax ; for debug
	
	mov eax, sys_write
	mov edi, 2 ; fd = 2
	mov edx, [rsi] ; 文字数
	add rsi, 4 ; 文字列の先頭アドレス
	syscall
	sub rsi, 4
	
	pop rax
	pop rcx
	pop rdx
	pop rdi

	ret

G_cout_num:
	push rsi
	push rax

	call G_set_dec_str_to_buf
	mov rsi, rax
	call G_cout_2

	pop rax
	pop rsi

	ret

section .text
; ----------------------------------------------------------------
; str_to_num
; 	数字文字列を数値へ変換する
; <<< IN
; rdi : 数字文字列のアドレス
; 	null terminated かつ 10 bytes 以内
; >>> OUT
; rax : 変換された数値
; --- DESTROY
; rdi, rsi, rcx, rdx, r8, r9, r10
str_to_num:
	mov ecx, 10 + 1
	xor eax, eax ; null
	cld ; clear DF
	repne scasb
	; while (rcx != 0 || ZF != 1)
	; {
	; 	if (*rdi == rax)
	;	{
	; 		ZF = 1;
	; 	}
	; 	++rdi;
	; 	--rcx;
	; }

	; rdi = rdi + length

	; ecx = (10 + 1) - length
	; (10 + 1) - (ecx + 1) = length - 1
	not ecx
	add ecx, 10 + 1 ; 文字数（null を除く）

	je str_to_num_ret ; null only の場合、0を返す

	mov esi, ecx ; 文字数 - 1
	mov r9d, 10 ; 乗数

	sub rdi, rcx ; rdi = 先頭 + 1
	sub rdi, 5 ; rdi = 先頭 - 4

	str_to_num_load:
		add rdi, 4
		mov r8d, [rdi]
		;; '~' で書いても良いかな
		and r8d, 0xcfcfcfcf ; ⇔ sub r8d, 0x30303030
		sub esi, 4 ; ecx = esi (= ecx - 4) になったら break
		jns str_to_num_add
		xor esi, esi ; ecx = esi (= 0) になったら break
		
	str_to_num_add:
		mul r9d ; 10倍

		mov r10d, 0xff ; この３行は、改善の余地があるか？
		and r10d, r8d
		add eax, r10d

		shr r8d, 8

		sub ecx, 1
		cmp ecx, esi
		jne str_to_num_add

		or esi, esi
		jne str_to_num_load

	str_to_num_ret:
	ret
