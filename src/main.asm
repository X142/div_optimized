global _start

extern G_cerr_LF
extern G_cerr_uint32_hex
extern G_cerr_uint64_hex
extern G_cerr_uint128_hex
extern G_cerr_string

bits 64 ; 64bit mode
; In 64bit mode, rip-relative-addressing is supported 
; for all instructions that uses ModR/M by encoding
; Mod = 00b, R/M = 101b : [rip + disp32]
default rel ; use rip-relative-addressing by default

; ================================================================
%define DEBUG
%define q_le_64bit
%define div_optimized
%define Cx_128_floor
%define m_p 0x002386f26fc10000
%define m_Cx_128_hi 0x0000000000000734
%define m_Cx_128_lo 0xaca5f6226f0ada61
%define m_pcs_check_points_in_div_set 4
%define m_DBG_cnt_div_hi 0x0000000000000000
%define m_DBG_cnt_div_lo 0x0000000000000fff
%define m_n_init_hi 0x0020000000000000
%define m_n_init_lo 0x0000000000000000
%define m_init_expected_quotient_hi 0x0000000000000000
%define m_init_expected_quotient_lo 0xe69594bec44de15b
%define m_init_expected_remainder 0x000a928ca5650000
%define m_init_k 0x00000000000003ff
%define m_increment_k 0x000008e1bc9bf03f
%define m_init_diff_p_minus_1_to_k m_p-1 - m_init_k
; ----------------------------------------------------------------
%define sys_exit 0x3c

; ================================================================
section .text
align 4096
_start:
    mov rbp, rsp

    call Test_div_optimized_128
    mov edi, eax

    mov rsp, rbp

    ; exit
    mov eax, sys_exit
    syscall

; ----------------------------------------------------------------
Test_div_optimized_128:
; ----------------------------------------------------------------
; 被除数 n, 除数 p に対し
; n = 0xffffffffffffffffffffffffffffffff から逆順に
; n mod p = (p-1), k, 1, 0 (1 < k < p-1)
; となる 4 点に対して、除算実行回数分、
; 周期的に除算を実行し、商と余りの検算を行う。
; 値 k は除算セット回数が進むごとに、
; k = 2 辺りから k = p-2 まで等間隔で周期的に増加する。
; 
; <<< ARGS
; -
; >>> RETURN
; rax : return-code
; --- DESTROY
; 
    %macro M_msg_DBG_cnt_and_expr 0
    ; rdi:rsi : 被除数
    ; r12:r13 : DBG_cnt
        push rcx
        push rdx
        push rsi
        push rdi

        mov rdx, rdi ; rdi -> rdx
        mov rcx, rsi ; rsi -> rcx

        mov rsi, L_msg_DBG_cnt
        call G_cerr_string
        mov rdi, r12
        call G_cerr_uint64_hex
        mov rdi, r13
        call G_cerr_uint64_hex

        call G_cerr_LF

        mov rdi, rdx
        call G_cerr_uint64_hex
        mov rdi, rcx
        call G_cerr_uint64_hex
        mov rsi, L_msg_op_div
        call G_cerr_string
        mov rdi, m_p
        call G_cerr_uint64_hex

        call G_cerr_LF

        pop rdi
        pop rsi
        pop rdx
        pop rcx
    %endmacro

    %macro M_div 0
        mov rdx, rdi
        mov rax, rsi
        mov rcx, m_p
        div rcx
    %endmacro

    %macro M_div_optimized 0
    ; rdi:rsi : 被除数
        push rdi ; 被除数の保存
        push rsi ; 被除数の保存
        call div_optimized_128
        pop rsi
        pop rdi
    %endmacro

    %macro M_check_quotient 0
    ; rcx:rax : 商
        %define r_expected_quotient_hi r14
        %define r_expected_quotient_lo r15

        %ifdef DEBUG
            push rsi
            push rdi

            mov rsi, L_msg_quotient
            call G_cerr_string
            mov rdi, rcx
            call G_cerr_uint64_hex
            mov rdi, rax
            call G_cerr_uint64_hex

            mov rsi, L_msg_expected_quotient
            call G_cerr_string
            mov rdi, r_expected_quotient_hi
            call G_cerr_uint64_hex
            mov rdi, r_expected_quotient_lo
            call G_cerr_uint64_hex

            call G_cerr_LF

            pop rdi
            pop rsi
        %endif

        %ifndef q_le_64bit
            cmp rcx, r_expected_quotient_hi
            jne L_failed_in_Test_div_optimized
        %endif

        cmp rax, r_expected_quotient_lo
        jne L_failed_in_Test_div_optimized
    %endmacro

    %macro M_msg_check_remainder 1
    ; %1 : 期待する余り
    ; rdx : 余り
        push rsi
        push rdi

        mov rsi, L_msg_remainder
        call G_cerr_string
        mov rdi, rdx
        call G_cerr_uint64_hex

        mov rsi, L_msg_expected_remainder
        call G_cerr_string
        mov rdi, %1
        call G_cerr_uint64_hex

        call G_cerr_LF

        pop rdi
        pop rsi
    %endmacro

    %macro M_check_remainder 1
    ; %1 : 期待する余り
    ; rdx : 余り
        %ifdef DEBUG
            M_msg_check_remainder %1
        %endif

        mov rcx, %1
        cmp rdx, rcx
        jne L_failed_in_Test_div_optimized
    %endmacro

    %macro M_check_remainder_imm32 1
    ; %1 : 期待する余り (imm32)
    ; rdx : 余り
        %ifdef DEBUG
            M_msg_check_remainder %1
        %endif

        cmp rdx, %1
        jne L_failed_in_Test_div_optimized
    %endmacro

    push r15
    push r14
    push r13
    push r12
    push rbx
    push rbp

    mov rbp, rsp

    ; rdi:rsi = 被除数の初期値
    mov rdi, m_n_init_hi
    mov rsi, m_n_init_lo

    ; r12:r13 = 除算実行回数
    mov r12, m_DBG_cnt_div_hi
    mov r13, m_DBG_cnt_div_lo

    ; r14:r15 = 期待する商の初期値
    mov r14, m_init_expected_quotient_hi
    mov r15, m_init_expected_quotient_lo

    push rbp ; rbp を保存

    ; rbx = diff_p_minus_1_to_k の初期値
    mov rbx, m_init_diff_p_minus_1_to_k
    ; rbp = k の初期値
    mov rbp, m_init_k

    L_check_endpoint:
        ; 0xffffffffffffffffffffffffffffffff % p != 0 の場合
        %if m_init_expected_remainder != 0
            %ifdef DEBUG
                M_msg_DBG_cnt_and_expr
            %endif

            ; 除算実行
            %ifdef div_optimized
                M_div_optimized
            %else
                M_div
            %endif

            ; 検算
            M_check_quotient
            M_check_remainder m_init_expected_remainder

            ; 除算実行回数のデクリメント
            xor edx, edx
            sub r13, 1
            sbb r12, rdx
            jc L_end_Test

            ; 次の被除数をセット
            mov rax, m_init_expected_remainder
            sub rsi, rax
            sbb rdi, rdx

            %ifdef DEBUG
                M_msg_DBG_cnt_and_expr
            %endif

            ; 除算実行
            %ifdef div_optimized
                M_div_optimized
            %else
                M_div
            %endif

            ; 検算
            M_check_quotient
            M_check_remainder_imm32 0

            ; 除算実行回数のデクリメント
            xor edx, edx
            sub r13, 1
            sbb r12, rdx
            jc L_end_Test

        %else
            %ifdef DEBUG
                M_msg_DBG_cnt_and_expr
            %endif

            ; 除算実行
            %ifdef div_optimized
                M_div_optimized
            %else
                M_div
            %endif

            ; 検算
            M_check_quotient
            M_check_remainder_imm32 0

            ; 除算実行回数のデクリメント
            xor edx, edx
            sub r13, 1
            sbb r12, rdx
            jc L_end_Test
        %endif

        ; 次の被除数のセット
        xor edx, edx
        sub rsi, 1
        sbb rdi, rdx

        ; 期待する商の更新
        sub r15, 1
        sbb r14, rdx

    L_loop_div_set:
        .at_n_mod_p_eq_p_minus_1:
            %ifdef DEBUG
                M_msg_DBG_cnt_and_expr
            %endif

            ; 除算実行
            %ifdef div_optimized
                M_div_optimized
            %else
                M_div
            %endif

            ; 検算
            M_check_quotient
            M_check_remainder m_p - 1

            ; 次の被除数をセット
            ; rsi:rdi -= (p-1)-k
            xor edx, edx
            sub rsi, rbx
            sbb rdi, rdx

        .at_n_mod_p_eq_k:
            %ifdef DEBUG
                M_msg_DBG_cnt_and_expr
            %endif

            ; 除算実行
            %ifdef div_optimized
                M_div_optimized
            %else
                M_div
            %endif

            ; 検算
            M_check_quotient
            M_check_remainder rbp

            ; 次の被除数をセット
            ; rsi:rdi -= k-1
            xor edx, edx
            lea rax, [rbp - 1] ; rax = k-1
            sub rsi, rax
            sbb rdi, rdx

        .at_n_mod_p_eq_1:
            %ifdef DEBUG
                M_msg_DBG_cnt_and_expr
            %endif

            ; 除算実行
            %ifdef div_optimized
                M_div_optimized
            %else
                M_div
            %endif

            ; 検算
            M_check_quotient
            M_check_remainder_imm32 1

            ; 次の被除数をセット
            xor edx, edx
            sub rsi, 1
            sbb rdi, rdx

        .at_n_mod_p_eq_0:
            %ifdef DEBUG
                M_msg_DBG_cnt_and_expr
            %endif

            ; 除算実行
            %ifdef div_optimized
                M_div_optimized
            %else
                M_div
            %endif

            ; 検算
            M_check_quotient
            M_check_remainder_imm32 0

            ; 次の被除数をセット
            xor edx, edx
            sub rsi, 1
            sbb rdi, rdx

        ; 除算実行回数のデクリメント
        sub r13, m_pcs_check_points_in_div_set
        sbb r12, rdx
        jc L_end_Test

        ; 期待する商の更新
        sub r15, 1
        sbb r14, rdx

        ; diff_p_minus_1_to_k, k の更新
        mov rdx, m_increment_k
        sub rbx, rdx ; (p-1)-k -> (p-1)-(k-1)
        je L_reset_k
        add rbp, rdx ; k-1 -> (k+1)-1

        jmp L_loop_div_set

    L_reset_k:
        mov rbx, m_init_diff_p_minus_1_to_k
        mov rbp, m_init_k
        jmp L_loop_div_set

    L_failed_in_Test_div_optimized:
        mov rsi, L_err_check_quotient_and_remainder
        call G_cerr_string

        ; return with exit-code 1
        mov eax, sys_exit
        mov edi, 1
        syscall

    L_end_Test:
    mov eax, 0 ; return-code 0

    pop rbp
 
    mov rsp, rbp
    pop rbp

    pop rbx
    pop r12
    pop r13
    pop r14
    pop r15

    ret

div_optimized_128:
; ----------------------------------------------------------------
; 128bit ÷ 64bit 高速化除算を実行する
; 通常の div 命令は、商が 64bit を超えると例外が発生するが、
; この関数では例外は発生しない
; 
; <<< ARGS
; rdi:rsi: 被除数
; >>> RETURN
; rcx:rax: 商
; rdx: 余り
; --- DESTROY
; rdi, rsi, rdx, rcx, r9, r10, r11
    push r14
    push r13
    push r12
    push rbx
    push rbp
    mov rbp, rsp

    ; rdx:rcx = Cx
    mov rdx, m_Cx_128_hi
    mov rcx, m_Cx_128_lo
    mov r8, m_p ; r8 = p

    ; rdi:rsi = n[127:64]:n[63:0]
    ; rbx:rcx = Cx[127:64]:Cx[63:0]
    ; r8 = p
    mov rbx, rdx

    ; rdx:rax = n[63:0]*Cx[63:0]
    mov rax, rsi
    mul rcx
    ; r9 = (n[63:0]*Cx[63:0])[127:63]
    mov r9, rdx

    ; rdx:rax = n[127:64]*Cx[63:0]
    mov rax, rdi
    mul rcx
    ; r10:r11 = rdx:rax = n[127:64]*Cx[63:0]
    mov r10, rdx
    mov r11, rax

    ; rdx:rax = n[63:0]*Cx[127:64]
    mov rax, rsi
    mul rbx
    ; r12:r13 = rdx:rax = n[63:0]*Cx[127:64]
    mov r12, rdx
    mov r13, rax

    ; rdx:rax = n[127:64]*Cx[127:64]
    mov rax, rdi
    mul rbx

    ; rdx:rax = q' = n*Cx*(1/x)
    xor r14, r14
    add r13, r11
    adc r12, r10

    adc rax, r14
    adc rdx, r14

    add r13, r9
    adc r12, r14

    adc rax, r12
    adc rdx, r14

    ; rbx:rcx = q' = rdx:rax
    mov rbx, rdx
    mov rcx, rax

    mov rax, rbx
    mul r8 ; rdx:rax = q'[127:64]*p < 2^64
    mov r9, rax ; r9 = rax

    mov rax, rcx
    mul r8 ; rdx:rax = q'[63:0]*p

    ; rdx:rax = q'*p
    add rdx, r9

    %ifdef Cx_128_floor

        %ifdef p_gt_2_to_the_power_of_63
            ; rsi = r' = n - q'*p
            sub rsi, rax
            sbb rdi, rdx

            ; r9:r10 = rdi:rsi
            mov r9, rdi
            mov r10, rsi
            ; r' - p < 0 ?
            xor r11, r11
            sub r10, r8
            sbb r9, r11
            jc L_end_div

            ; rbx:rcx = q = q' + 1
            add rcx, 1
            adc rbx, r11

            ; rsi = r = r' - p
            mov rsi, r10

        %else
            ; n - (q-1)*p = r + p < 2^64

            ; rsi = r' = n - q'*p
            sub rsi, rax

            ; r' - p < 0 ?
            cmp rsi, r8
            jc L_end_div

            ; rbx:rcx = q = q' + 1
            xor r9, r9
            add rcx, 1
            adc rbx, r9

            ; rsi = r = r' - p
            sub rsi, r8

        %endif

    %else
        jc L_overflowed_q_prime_p ; q'*p = (q+1)*p >= 2^128 ?

        ; rdi:rsi = r' = n - q'*p
        sub rsi, rax
        sbb rdi, rdx

        ; r' > 0 ?
        jnc L_end_div

        jmp L_dec_qutient

        L_overflowed_q_prime_p:
            ; rbx:rcx = q = q' - 1
            xor r9, r9
            sub rcx, 1
            sbb rbx, r9

            sub rax, r8 ; rax = q*p = q'*p - p

            sub rsi, rax ; rsi = r = n - q*p

            jmp L_end_div

        L_dec_qutient:
            ; rbx:rcx = q = q' - 1
            xor r9, r9
            sub rcx, 1
            sbb rbx, r9

            add rsi, r8 ; rsi = r = r' + p

    %endif

    L_end_div:
        mov rax, rcx
        mov rcx, rbx
        mov rdx, rsi

    mov rsp, rbp
    pop rbp
    pop rbx
    pop r12
    pop r13
    pop r14

    ret

; ================================================================
section .data
    L_msg_DBG_cnt:
        DB "DBG_cnt: ",0xa,0

    L_msg_op_div:
        DB "       ÷",0xa,0

    L_msg_quotient:
        DB "商の計算結果: ",0xa,0
    L_msg_remainder:
        DB "余りの計算結果: ",0xa,0
    L_msg_expected_quotient:
        DB "期待する商: ",0xa,0
    L_msg_expected_remainder:
        DB "期待する余り: ",0xa,0

; ----------------------------------------------------------------
    L_err_check_quotient_and_remainder:
        DB "!! 商または余りが間違っています",0xa,0
