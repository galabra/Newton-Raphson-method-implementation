;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

section .data
    
    format_epsilon: db "epsilon = %lg", 10, 0
    format_order:   db "order = %ld", 10, 0
    format_coeff:   db "coeff %ld = %lf %lf", 10, 0
    format_initial: db "initial = %lf %lf", 0
    format_initial_o: db "initial = %lf %lf", 10, 0
    format_out:     db "root = %.16lg %.16lg", 10, 0
    
    ; testing
    break:           db "---", 10, 0
    format_test_val: db "test val: %lf", 10, 0
    format_breakpoint: db "break point %ld", 10, 0
    format_starting_numerator: db "=== Starting to calculate numerator ===", 10, 0
    format_starting_create_denominator: db "=== Starting to create denominator ===", 10, 0
    format_starting_denominator: db "=== Starting to calculate denominator ===", 10, 0
    format_complex_pow: db  "Power function was called: (%lf + %lf i) ^ %ld", 10, 0
    format_test:    db "test: %lf", 10, 0
    format_complex_pow_final: db " = %lf + %lf i", 10, 0
    format_calculate_coefficients: db "====== .calculate_coefficients is called for coefficient #%ld", 10, 0
    format_complex_mul: db  "Multiplication function was called: (%lf + %lf i) * (%lf + %lf i)", 10, 0
    
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

section .bss    ; variables declaration
    
    epsilon             resq    1
    order               resd    1
    init_real           resq    1
    init_img            resq    1
    r1                  resq    1   ; used for arithmetic operations as lhs
    i1                  resq    1   ; used for arithmetic operations as lhs
    r2                  resq    1   ; used for arithmetic operations as rhs
    i2                  resq    1   ; used for arithmetic operations as rhs
    result_real         resq    1   ; used for arithmetic operations as result
    result_img          resq    1   ; used for arithmetic operations as result
    real_comps_array    resq    1               ; a pointer to the array of the coefficients' real components
    img_comps_array     resq    1               ; a pointer to the array of the coefficients' imaginary components
    real_comps_derivative_array     resq    1
    img_comps_derivative_array      resq    1
    specific_coeff_real_address     resq    1   ; a pointer to a specific cell in the array of the coefficients' real components
    specific_coeff_img_address      resq    1   ; a pointer to a specific cell in the array of the coefficients' img components
    specific_coeff_real_address_derivative resq    1   ; a pointer to a specific cell in the array of the coefficients' real components
    specific_coeff_img_address_derivative  resq    1   ; a pointer to a specific cell in the array of the coefficients' img components
    new_coeff_index     resq    1
    new_coeff_real      resq    1
    new_coeff_img       resq    1
    numerator_real      resq    1
    numerator_img       resq    1
    denominator_real    resq    1
    denominator_img     resq    1
    ans_real            resq    1   ; current ans (best guess)
    ans_img             resq    1   ; current ans (best guess)
    counter             resq    1
    counter2            resq    1
    testindx            resq    1

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

section .text
    
    extern printf
    extern scanf
    extern calloc
    
    global main
    
    ;testing
    %macro testbp 1
        mov     rdi, format_breakpoint
        mov     rsi, %1
        mov     rax, 1
        call    printf
    %endmacro
    
    %macro break 0
        mov     rdi, break
        mov     rax, 0
        call    printf
    %endmacro
    
    %macro testval 1
        mov     rdi, format_test_val
        movsd   xmm0, %1
        mov     rax, 1
        call    printf
    %endmacro
    
    %macro new_array 1  ; creates a new array of dynamic length. Each cell with size 8.
        mov rax, %1
        mov rdi, rax    ; rdi contains the 1st parameter, BufSize (for calloc)
        mov rsi, 8      ; rsi contains the 2nd parameter, sizeof(char) (for scanf)
        call calloc
    %endmacro

    %macro calc_offset 0
    ; puts in 'specific_coeff_{real/img}_address' the addresses of the (counter)th coefficient
        mov     r9, qword[counter]             ; move counter into r9
        sal     r9, 3                          ; multiply by 8
        add     r9, qword[real_comps_array]    ; r9 <-- r9 + array's address = address + offset
        fld     qword[r9]                      ; push current (address + offset)
        fstp    qword[specific_coeff_real_address]   ;   into 'new_coeff_real_address'
        
        mov     r9, qword[counter]             ; the same for the imaginary components
        sal     r9, 3
        add     r9, qword[img_comps_array]
        fld     qword[r9]
        fstp    qword[specific_coeff_img_address]
    %endmacro
    
    %macro calc_offset_derivative 0
    ; puts in 'specific_coeff_{real/img}_address' the addresses of the (counter)th coefficient
        mov r13, qword[counter]
        sal r13, 3                   ; r13 helps to get the last cell in the array
        mov r15, qword[real_comps_derivative_array]
        mov r14, qword[r15 + r13]
        mov qword[specific_coeff_real_address_derivative], r14
        ;;;;;;;;;;;;;;;;
        
        ;mov     r9, qword[counter]             ; move counter into r9
        ;sal     r9, 3                          ; multiply by 8
        ;add     r9, qword[real_comps_derivative_array]    ; r9 <-- r9 + array's address = address + offset
        ;fld     qword[r9]                      ; push current (address + offset)
        ;fstp    qword[r14]   ;   into 'new_coeff_real_address'
        
        mov     r9, qword[counter]             ; the same for the imaginary components
        sal     r9, 3
        add     r9, qword[img_comps_derivative_array]
        fld     qword[r9]
        fstp    qword[specific_coeff_img_address_derivative]
    %endmacro
    
    calc_numerator:       ; calculates f(X) for X = (ans_real, ans_img)
    ; iterates through the arrays and multiply by X's relevant component
    ; stores the result in (numerator_real, numerator_img)
        enter 0, 0
        
            ;testing
            ;mov     rdi, format_starting_numerator
            ;mov     rax, 0
            ;call    printf
        
        mov qword[counter], 0
        calc_offset                             ; firstly, calculate the 0th coefficient
        fld qword[specific_coeff_real_address]
        fstp qword[numerator_real]
        fld qword[specific_coeff_img_address]
        fstp qword[numerator_img]
        inc qword[counter]
        
        .calculate_coefficients_num:
            calc_offset
            fld     qword[ans_real]
            fld     qword[ans_img]
            fstp    qword[i1]
            fstp    qword[r1]   ; initialize (r1,i1) in order to use power-by-counter operation
            call complex_pow    ; result = (r1,i1)^counter
            fld     qword[result_real]
            fld     qword[result_img]
            fstp    qword[i1]   ; (r1,i1) <-- result
            fstp    qword[r1]
            fld     qword[specific_coeff_real_address]
            fld     qword[specific_coeff_img_address]
            fstp    qword[i2]   ; (r2,i2) <-- current coefficient
            fstp    qword[r2]
            call complex_mul    ; result = (r1,i1)*(r2,i2)
            fld     qword[result_real]
            fld     qword[result_img]
            fstp    qword[i1]
            fstp    qword[r1]   ; (r1,i1) <-- result
            fld     qword[numerator_real]
            fld     qword[numerator_img]
            fstp    qword[i2]
            fstp    qword[r2]   ; (r2,i2) <-- numerator
            call complex_add    ; result = (r1,i1) + (r2,i2)
            fld     qword[result_real]
            fld     qword[result_img]
            fstp    qword[numerator_img]    ; numerator <-- result
            fstp    qword[numerator_real]   ; numerator <-- result
            
                    ;testing
                    ;mov     rdi, format_coeff
                    ;mov     rsi, qword[counter]
                    ;movsd   xmm0, qword [numerator_real]
                    ;movsd   xmm1, qword [numerator_img]
                    ;mov     rax, 3
                    ;call    printf
        
        .calculate_coefficients_num_loop:
            inc     qword[counter]
            mov     r9, qword[order]
            ;inc     r9                     ; r9 <-- order+1
            cmp     qword[counter], r9
            jle     .calculate_coefficients_num
        
        leave
        ret
        
        
    calc_denominator:       ; calculates f(X) for X = (ans_real, ans_img)
    ; iterates through the arrays and multiply by X's relevant component
    ; stores the result in (denominator_real, denominator_img)
        enter 0, 0
        
            ;testing
            ;mov     rdi, format_starting_denominator
            ;mov     rax, 0
            ;call    printf
        
        mov qword[counter], 0
        calc_offset_derivative                       ; firstly, calculate the 0th coefficient
        fld qword[specific_coeff_real_address_derivative]
        fstp qword[denominator_real]
        fld qword[specific_coeff_img_address_derivative]
        fstp qword[denominator_img]
        inc qword[counter]
        
        .calculate_coefficients_denom:
            calc_offset_derivative
            fld     qword[ans_real]
            fld     qword[ans_img]
            fstp    qword[i1]
            fstp    qword[r1]   ; initialize (r1,i1) in order to use power-by-counter operation
            call complex_pow    ; result = (r1,i1)^counter
            
            
            fld     qword[result_real]
            fld     qword[result_img]
            fstp    qword[i1]   ; (r1,i1) <-- result
            fstp    qword[r1]
            fld     qword[specific_coeff_real_address_derivative]
            fld     qword[specific_coeff_img_address_derivative]
            fstp    qword[i2]   ; (r2,i2) <-- current coefficient
            fstp    qword[r2]
            call complex_mul    ; result = (r1,i1)*(r2,i2)
            fld     qword[result_real]
            fld     qword[result_img]
            fstp    qword[i1]
            fstp    qword[r1]   ; (r1,i1) <-- result
            fld     qword[denominator_real]
            fld     qword[denominator_img]
            fstp    qword[i2]
            fstp    qword[r2]   ; (r2,i2) <-- denominator
            call complex_add    ; result = (r1,i1) + (r2,i2)
            fld     qword[result_real]
            fld     qword[result_img]
            fstp    qword[denominator_img]    ; denominator <-- result
            fstp    qword[denominator_real]   ; denominator <-- result
            
                    ;testing
                    ;mov     rdi, format_coeff
                    ;mov     rsi, qword[counter]
                    ;movsd   xmm0, qword [denominator_real]
                    ;movsd   xmm1, qword [denominator_img]
                    ;mov     rax, 3
                    ;call    printf
        
        .calculate_coefficients_denom_loop:
            inc     qword[counter]
            mov     r9, qword[order]
            sub     r9, 1                   ; r9 <-- order-1 (because it's the derivative)
            cmp     qword[counter], r9
            jle     .calculate_coefficients_denom
        
        leave
        ret
        
        
    test:
        enter 0, 0
        
        call calc_numerator
        
        leave
        ret
    
    main:
        enter 0, 0              ; prepare a frame
        finit                   ; initialize the x87 subsystem
        mov rax, 1
        mov     qword[testindx], 0
                
        call parse_input
        ;break
        call    create_denominator  ; initialize denominator
        ;call print_all
        ;break       
        call newton_raphson
        
        mov     rax, 0                  ; return 0 (like in C)
        leave       ; end of main
        ret
        
        
    newton_raphson:
        enter 0, 0
        
        .newton_raphson_body:
            call calc_numerator
            call calc_denominator
            fld     qword[numerator_real]
            fld     qword[numerator_img]
            fstp    qword[i1]
            fstp    qword[r1]               ; (r1,i1) <-- numerator
            fld     qword[denominator_real]
            fld     qword[denominator_img]
            fstp    qword[i2]
            fstp    qword[r2]               ; (r2,i2) <-- denominator
            call complex_div
            fld     qword[result_real]
            fld     qword[result_img]
            fstp    qword[i2]
            fstp    qword[r2]
            fld     qword[ans_real]
            fld     qword[ans_img]
            fstp    qword[i1]
            fstp    qword[r1]
            call complex_sub
            fld     qword[result_real]
            fld     qword[result_img]
            fstp    qword[ans_img]
            fstp    qword[ans_real]         ; zn+1 = zn - (f/f')
            
        .newton_raphson_loop:               ; while (||z|| >= epsilon)
            fld     qword[numerator_real]
            fld     qword[numerator_real]
            fmul
            fld     qword[numerator_img]
            fld     qword[numerator_img]
            fmul
            fadd
            fsqrt
            fstp    qword[result_real]      ; result <-- ||z||
            cmp     qword[result_real], epsilon
            jge     .newton_raphson_body    ; repeat loop body
        
        .finish:
            mov     rdi, format_out
            movsd   xmm0, qword [ans_real]
            movsd   xmm1, qword [ans_img]
            mov     rax, 2
            call    printf      ; print coefficient
            leave
            ret
        
        
    parse_input:
        enter 0, 0
        mov     qword[counter], 0
        mov     rdi, format_epsilon     ; rdi contains the 1st parameter, format (for scanf)
        mov     rsi, epsilon            ; rsi contains the 2nd parameter, target (for scanf)
        mov     rax, 0                  ; scanf requires 0 arguments
        call scanf                      ; read "epsilon"
        
        mov     rdi, format_order
        mov     rsi, order
        mov     rax, 0
        call scanf                      ; read "order"
        
        mov     rax, qword[order]           ; set 2 arrays for coefficients (for real and imaginary parts)
        inc     rax                         ; array with n elements has size of n+1
        mov     rbx, rax
        new_array rbx                       ; creates a new array and stores its address in rax
        mov qword[real_comps_array], rax    ; store the real components address
        new_array rbx                       ; creates a new array and stores its address in rax
        mov qword[img_comps_array], rax     ; store the real components address
        
        sub     rbx, 1                      ; the derivative array has 1 less coefficient
        new_array rbx
        mov qword[real_comps_derivative_array], rax
        new_array rbx
        mov qword[img_comps_derivative_array], rax
        
        .read_coefficients:
            mov     rdi, format_coeff           ; 1st argument
            mov     rsi, new_coeff_index        ; 2nd argument (integer)
            mov     rdx, new_coeff_real         ; 3rd argument
            mov     rcx, new_coeff_img          ; 4th argument
            mov     rax, 0
            call scanf                          ; read coefficient
            
            mov     r11, qword[new_coeff_index]     ; move current index into r11
            sal     r11, 3                          ; multiply by 8
            add     r11, qword[real_comps_array]    ; r11 <-- r11 + array's address = address + offset
            fld     qword[new_coeff_real]           ; push current real part
            fstp    qword[r11]                      ;   into the new array's address
            
            ; initialize derivative array
            ;mov     r11, qword[new_coeff_index]     ; move current index into r11
            ;sal     r11, 3                          ; multiply by 8
            ;add     r11, qword[real_comps_derivative_array]    ; r11 <-- r11 + array's address = address + offset
            ;add     qword[new_coeff_real], 3
            ;fld     qword[new_coeff_real]           ; push current real part
            ;sub     qword[new_coeff_real], 3
            ;fstp    qword[r11]                      ;   into the new array's address
            
            mov     r11, qword[new_coeff_index]
            sal     r11, 3
            add     r11, qword[img_comps_array]
            fld     qword[new_coeff_img]
            fstp    qword[r11]
            
            ; initialize derivative array
            ;mov     r11, qword[new_coeff_index]     ; move current index into r11
            ;sal     r11, 3                          ; multiply by 8
            ;add     r11, qword[img_comps_derivative_array]    ; r11 <-- r11 + array's address = address + offset
            ;fld     qword[new_coeff_img]            ; push current real part
            ;fstp    qword[r11]                      ;   into the new array's address
            
        .read_coefficients_loop:
            inc     qword[counter]          ; counter ++
            mov     r9, qword[order]        ; r9 <-- order
            inc     r9                      ; r9 <-- order+1
            cmp     qword[counter], r9      ; if (counter < order+1)
            jl      .read_coefficients      ; repeat loop body
        
        
        mov     rdi, format_initial         ; 1st argument
        mov     rsi, init_real              ; 2nd argument
        mov     rdx, init_img               ; 3rd argument
        mov     rax, 0
        call scanf                          ; read "initial"
        
        fld     qword[init_real]
        fld     qword[init_img]
        fstp    qword[ans_img]              ; initialize current ans
        fstp    qword[ans_real]             ; initialize current ans
        
        leave       ; end of parse_input
        ret
        
    
    create_denominator:
        enter 0, 0
        
        mov qword[counter], 0
        .read_coefficients_denominator:
            inc     qword[counter]
            calc_offset
            fild    qword[counter]
            fld     qword[specific_coeff_real_address]
            fmul
            fstp    qword[result_real]
            mov     r11, qword[result_real]
            
            mov     r13, qword[counter]
            sub     r13, 1
            sal     r13, 3
            mov     r15, qword[real_comps_derivative_array]
            mov     qword[r15 + r13], r11
            
            ; for imaginary
            fild    qword[counter]
            fld     qword[specific_coeff_img_address]
            fmul
            fstp    qword[result_img]
            mov     r11, qword[result_img]
            
            mov     r13, qword[counter]
            sub     r13, 1
            sal     r13, 3
            mov     r15, qword[img_comps_derivative_array]
            mov     qword[r15 + r13], r11
            ; until here img
            
        .read_coefficients_denominator_loop:
            mov     r9, qword[order]        ; r9 <-- order
           ;inc     r9                      ; denominator has order-1 cells
            cmp     qword[counter], r9      ; if (counter < order)
            jl      .read_coefficients_denominator      ; repeat loop body
        
        leave       ; end of parse_input
        ret
        
        
    print_all:
        enter 0, 0
        mov     rdi, format_epsilon
        movsd   xmm0, qword [epsilon]
        mov     rax, 1
        call    printf      ; print epsilon
        
        mov     rdi, format_order
        mov     rsi, qword [order]          ; 'order' is an integer, therefore it's located in rsi
        mov     rax, 1                      ; as the 2nd argument (rather than xmm0)
        call    printf      ; print order
        
        mov qword[counter], 0
        .write_coefficients:
            calc_offset
            
            mov     rdi, format_coeff
            mov     rsi, qword[counter]
            movsd   xmm0, qword [specific_coeff_real_address]
            movsd   xmm1, qword [specific_coeff_img_address]
            mov     rax, 3
            call    printf      ; print coefficient
        
        .write_coefficients_loop:
            inc     qword[counter]
            mov     r9, qword[order]
            inc     r9                     ; r9 <-- order+1
            cmp     qword[counter], r9
            jl      .write_coefficients
        
        mov     rdi, format_initial_o
        movsd   xmm0, qword [init_real]
        movsd   xmm1, qword [init_img]
        mov     rax, 2
        call    printf          ; print initial
        
        mov     rdi, format_out
        movsd   xmm0, qword [ans_real]
        movsd   xmm1, qword [ans_img]
        mov     rax, 2
        call    printf          ; print ans
        
        leave       ; end of print_all
        ret
        
    
    complex_add:
        enter 0, 0
        mov     qword[result_real], 0
        mov     qword[result_img],  0
        
        fld qword [r1]          ; load the real component of the 1st complex number into ST(0)
        fld qword [r2]          ; load the real component of the 2nd complex number into ST(0)
        fadd                    ; add ST(0) to ST(1) and return the result to ST(0)
        fstp qword [result_real]; convert result to floating-point format and pop
        
        fld qword [i1]          ; load the imaginary component of the 1st complex number into ST(0)
        fld qword [i2]          ; load the imaginary component of the 2nd complex number into ST(0)
        fadd                    ; add ST(0) to ST(1) and return the result to ST(0)
        fstp qword [result_img] ; convert result to floating-point format and pop
        
        leave
        ret

        
    complex_sub:
        enter 0, 0
        mov     qword[result_real], 0
        mov     qword[result_img],  0
        
        fld qword [r1]          ; load the real component of the 1st complex number into ST(0)
        fld qword [r2]          ; load the real component of the 2nd complex number into ST(0)
        fsub                    ; add ST(0) to ST(1) and return the result to ST(0)
        fstp qword [result_real]; convert result to floating-point format and pop
        
        fld qword [i1]          ; load the imaginary component of the 1st complex number into ST(0)
        fld qword [i2]          ; load the imaginary component of the 2nd complex number into ST(0)
        fsub                    ; add ST(0) to ST(1) and return the result to ST(0)
        fstp qword[result_img]  ; convert result to floating-point format and pop
        
        leave
        ret
        
    
    complex_div:
        enter 0, 0
        mov     qword[result_real], 0
        mov     qword[result_img],  0
        
        fld     qword[r1]
        fld     qword[r2]
        fmul    ; ST(0) = ac
        fld     qword[i1]
        fld     qword[i2]
        fmul
        fadd    ; ST(0) = ac+bd
        
        fld     qword[r2]
        fld     qword[r2]
        fmul    ; ST(0) = c^2
        fld     qword[i2]
        fld     qword[i2]
        fmul    ; ST(0) = d^2
        fadd    ; ST(0) = c^2 + d^2
        fdiv    ; ST(0) = ST(1)/ST(0)
        fstp    qword[result_real]
        
        ; img part:
        fld     qword[i1]
        fld     qword[r2]
        fmul    ; ST(0) = bc
        fld     qword[r1]
        fld     qword[i2]
        fmul    ; ST(0) = ad
        fsub    ; ST(0) = bc-ad
        
        fld     qword[r2]
        fld     qword[r2]
        fmul    ; ST(0) = c^2
        fld     qword[i2]
        fld     qword[i2]
        fmul    ; ST(0) = d^2
        fadd    ; ST(0) = c^2 + d^2
        fdiv    ; ST(0) = ST(1)/ST(0)
        fstp    qword[result_img]
        leave
        ret
        
    
    complex_mul:    ; (a+bi)*(c+di) = (ac-bd) + (bc+ad)i
        enter 0, 0
        
        mov     qword[result_real], 0
        mov     qword[result_img],  0
        
        fld     qword[r1]
        fld     qword[r2]
        fmul    ; ST(0) = ac
        fld     qword[i1]
        fld     qword[i2]
        fmul    ; ST(0) = bd;  ST(1) = ac
        fsub    ; ac-bd
        fstp    qword[result_real]
        
        fld     qword[i1]
        fld     qword[r2]
        fmul    ; bc
        fld     qword[r1]
        fld     qword[i2]
        fmul    ; ad
        fadd    ; bc + ad
        fstp    qword[result_img]
        leave
        ret
        
        
    complex_pow:                ; result = (r1,i1)^counter
                                ; assuming that counter >= 1
        enter 0, 0
        
        mov     qword[result_real], 0
        mov     qword[result_img],  0
        mov     qword[counter2], 1
        fld     qword[r1]
        fld     qword[i1]
        fstp    qword[result_img]       ; result <-- (r1, i1) * 1
        fstp    qword[result_real]
        
        mov     r9, qword[counter]
        cmp     qword[counter2], r9
        jge     .finish_complex_pow     ; return if counter2 = 0 >= counter
        
        .calculate_pow:
            fld     qword[result_real]
            fld     qword[result_img]
            fstp    qword[i2]       ; (r2,i2) <-- result
            fstp    qword[r2]
            call complex_mul        ; result = (r1,i1) * (r2,i2)           
            ;fld     qword[result_real]
            ;fld     qword[result_img]
            ;fstp    qword[i2]
            ;fstp    qword[r2]   ; copy result into (r2,i2)
        
        .calculate_pow_loop:
            inc     qword[counter2]
            mov     r9, qword[counter]
            cmp     qword[counter2], r9
            jl      .calculate_pow
        
        .finish_complex_pow:            
            leave
            ret