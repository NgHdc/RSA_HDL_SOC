`timescale 1ns / 1ps

// Defines cho module inverter
`define UPDATING 3'd1
`define CHECK 3'd2
`define HOLDING 3'd3

// Defines cho module mod_exp (và có th? c? inverter n?u dùng chung)
`define UPDATE 2'd1
`define HOLD 2'd2


//======================================================================
// Module: mod (Th?c hi?n phép chia l?y d? và th??ng)
//======================================================================
module mod #(
    parameter WIDTH = 19 // Giá tr? m?c ??nh, s? ???c ghi ?è khi instantiate
) (
    input [WIDTH-1:0] a,
    input [WIDTH-1:0] n,
    output [WIDTH-1:0] R, // Remainder (s? d?)
    output [WIDTH-1:0] Q  // Quotient (th??ng s?)
);

    reg [WIDTH-1:0] A_reg;
    reg [WIDTH-1:0] N_reg;
    reg [WIDTH:0] p_temp; // p_temp có ?? r?ng WIDTH+1 bits
    integer i;

    always @(a or n) begin
        A_reg = a;
        N_reg = n;
        p_temp = 0;
        for (i = 0; i < WIDTH; i = i + 1) begin
            if (WIDTH == 0) begin
                // Không làm gì ho?c gán giá tr? m?c ??nh
            end else if (WIDTH == 1) begin
                p_temp = {p_temp[0], A_reg[WIDTH-1]};
                // A_reg[WIDTH-1:1] không t?n t?i
            end else begin // WIDTH >= 2
                p_temp = {p_temp[WIDTH-2:0], A_reg[WIDTH-1]};
                A_reg[WIDTH-1:1] = A_reg[WIDTH-2:0];
            end

            if (N_reg != 0) begin // Tránh chia cho 0
                p_temp = p_temp - N_reg;
                if (p_temp[WIDTH] == 1'b1) begin // Ki?m tra bit d?u (MSB) c?a p_temp [WIDTH:0]
                    A_reg[0] = 1'b0;
                    p_temp = p_temp + N_reg;
                end else begin
                    A_reg[0] = 1'b1;
                end
            end else begin // X? lý tr??ng h?p chia cho 0 (n?u c?n)
                A_reg[0] = 1'bx; // Ho?c m?t giá tr? l?i khác
                // i // <--- DÒNG NÀY GÂY L?I, ?Ã B? XÓA HO?C GHI CHÚ
            end
        end
    end

    assign R = p_temp[WIDTH-1:0];
    assign Q = A_reg;
endmodule


//======================================================================
// Module: mod_exp (Th?c hi?n phép l?y th?a theo modulo)
//======================================================================
module mod_exp #(
    parameter WIDTH = 32 // Giá tr? m?c ??nh, s? ???c ghi ?è
) (
    input [WIDTH*2-1:0] base,
    input [WIDTH*2-1:0] modulo,
    input [WIDTH*2-1:0] exponent,
    input clk,
    input reset,
    output finish, // B? 'logic'
    output [WIDTH*2-1:0] result // B? 'logic'
);

    reg [WIDTH*2-1:0] base_reg, modulo_reg, exponent_reg, result_reg;
    reg [1:0] state; // `UPDATE, `HOLD (2-bit defines)

    wire [WIDTH*2-1:0] result_mul_base = result_reg * base_reg;
    wire [WIDTH*2-1:0] result_next_remainder;
    wire [WIDTH*2-1:0] base_squared = base_reg * base_reg;
    wire [WIDTH*2-1:0] base_next_remainder;
    wire [WIDTH*2-1:0] exponent_next = exponent_reg >> 1;

    // Dây cho c?ng Q c?a module mod (th??ng không c?n thi?t cho k?t qu? cu?i c?a phép modulo)
    wire [WIDTH*2-1:0] q_temp_bsm;
    wire [WIDTH*2-1:0] q_temp_rmbm;

    assign finish = (state == `HOLD); // `HOLD là 2'd2
    assign result = result_reg;

    mod #(
        .WIDTH(WIDTH*2) // Module 'mod' c?n ho?t ??ng v?i ?? r?ng WIDTH*2
    ) base_squared_mod_inst ( // ??i tên instance
        .a(base_squared),
        .n(modulo_reg),
        .R(base_next_remainder),
        .Q(q_temp_bsm)
    );

    mod #(
        .WIDTH(WIDTH*2)
    ) result_mul_base_mod_inst ( // ??i tên instance
        .a(result_mul_base),
        .n(modulo_reg),
        .R(result_next_remainder),
        .Q(q_temp_rmbm)
    );

    always @(posedge clk) begin
        if (reset) begin
            base_reg <= base;
            modulo_reg <= modulo;
            exponent_reg <= exponent;
            result_reg <= {{WIDTH*2-1{1'b0}}, 1'b1}; // Giá tr? 1 v?i ?? r?ng WIDTH*2
            state <= `UPDATE; // `UPDATE là 2'd1
        end else begin
            case (state)
                `UPDATE: begin
                    if (exponent_reg != {{WIDTH*2{1'b0}}}) begin
                        if (exponent_reg[0]) begin
                            result_reg <= result_next_remainder;
                        end
                        base_reg <= base_next_remainder;
                        exponent_reg <= exponent_next;
                        // state <= `UPDATE; // Không c?n thi?t, vòng l?p t? nhiên
                    end else begin
                        state <= `HOLD;
                    end
                end
                `HOLD: begin
                    // Gi? tr?ng thái
                end
            endcase
        end
    end
endmodule


//======================================================================
// Module: inverter (Tìm khóa e và d cho RSA)
//======================================================================
module inverter #(
    parameter WIDTH = 32 // Giá tr? m?c ??nh, s? ???c ghi ?è
) (
    input [WIDTH-1:0] p,
    input [WIDTH-1:0] q,
    input clk,
    input reset,
    output finish, // B? 'logic'
    output [WIDTH*2-1:0] e,
    output [WIDTH*2-1:0] d
);

    reg [WIDTH*2-1:0] totient_reg, a_reg, b_reg, y_reg, y_prev_reg;
    reg [2:0] state; // `UPDATING, `CHECK, `HOLDING (3-bit defines)
    reg [WIDTH-1:0] e_reg_internal;

    wire [WIDTH*2-1:0] totient_val = (p-1)*(q-1);
    wire [WIDTH*2-1:0] quotient_from_mod, remainder_from_mod;
    wire [WIDTH*2-1:0] y_next_val = y_prev_reg - (quotient_from_mod * y_reg);
    wire [WIDTH-1:0] e_plus_2_val = e_reg_internal + 2;

    assign finish = (state == `HOLDING); // `HOLDING là 3'd3
    assign e = {{WIDTH{1'b0}}, e_reg_internal}; // M? r?ng bit 0 cho e_reg_internal
    assign d = y_prev_reg;

    mod #(
        .WIDTH(WIDTH*2)
    ) x_mod_y_inst ( // ??i tên instance
        .a(a_reg),
        .n(b_reg),
        .R(remainder_from_mod),
        .Q(quotient_from_mod)
    );

    always @(posedge clk) begin
        if (reset) begin
            totient_reg <= (p-1)*(q-1);
            a_reg <= (p-1)*(q-1); // S?a: nên gán t? totient_val ho?c (p-1)*(q-1)
            b_reg <= {{WIDTH*2-1{1'b0}}, 3'd3}; // e_initial = 3
            e_reg_internal <= 3;
            y_reg <= {{WIDTH*2-1{1'b0}}, 1'b1}; // y = 1
            y_prev_reg <= {{WIDTH*2{1'b0}}};    // y_prev = 0
            state <= `UPDATING; // `UPDATING là 3'd1
        end else begin
            case (state)
                `UPDATING: begin
                    if (b_reg != {{WIDTH*2{1'b0}}}) begin
                        a_reg <= b_reg;
                        b_reg <= remainder_from_mod;
                        y_prev_reg <= y_reg;
                        y_reg <= y_next_val;
                        // state <= `UPDATING; // Không c?n thi?t
                    end else begin
                        state <= `CHECK;
                    end
                end
                `CHECK: begin
                    // ??m b?o y_prev_reg ???c ?i?u ch?nh n?u nó âm (d = y_prev_reg mod totient_reg)
                    // Logic hi?n t?i ch? ki?m tra y_prev_reg[MSB] == 0 (d??ng)
                    if (a_reg == {{WIDTH*2-1{1'b0}},1'b1} && y_prev_reg[WIDTH*2-1] == 1'b0) begin
                        state <= `HOLDING;
                    end else begin
                        a_reg <= totient_reg; // Reset a_reg v? totient cho l?n th? e m?i
                        e_reg_internal <= e_plus_2_val;
                        b_reg <= {{WIDTH{1'b0}}, e_plus_2_val}; // C?p nh?t b_reg v?i e m?i
                        y_reg <= {{WIDTH*2-1{1'b0}}, 1'b1};
                        y_prev_reg <= {{WIDTH*2{1'b0}}};
                        state <= `UPDATING;
                    end
                end
                `HOLDING: begin
                    // Gi? tr?ng thái
                end
            endcase
        end
    end
endmodule


//======================================================================
// Module: control (Module chính ?i?u khi?n)
//======================================================================
module control #(
    parameter WIDTH = 32 // Giá tr? m?c ??nh
) (
    input [WIDTH-1:0] p, q,
    input clk,
    input reset,            // Reset cho module inverter
    input reset1,           // Reset cho module mod_exp
    input encrypt_decrypt,
    input [WIDTH-1:0] msg_in,
    output [WIDTH*2-1:0] msg_out,
    output mod_exp_finish
);

    wire inverter_finish_internal;
    wire [WIDTH*2-1:0] e_key, d_key;
    wire [WIDTH*2-1:0] current_exponent = encrypt_decrypt ? e_key : d_key;
    wire [WIDTH*2-1:0] current_modulo = p * q; // Phép nhân này là t? h?p

    // Các thanh ghi này giúp ?n ??nh ??u vào cho mod_exp qua các chu k? clock
    // và ??m b?o current_exponent, current_modulo ???c l?y giá tr? ?úng ??n
    reg [WIDTH*2-1:0] exp_reg_for_modexp, msg_reg_for_modexp;
    reg [WIDTH*2-1:0] mod_reg_for_modexp;

    always @(posedge clk) begin
        exp_reg_for_modexp <= current_exponent;
        mod_reg_for_modexp <= current_modulo;
        // M? r?ng msg_in t? WIDTH bit lên WIDTH*2 bit b?ng cách thêm bit 0 ? MSB
        // ?? phù h?p v?i ??u vào 'base' c?a mod_exp
        msg_reg_for_modexp <= {{(WIDTH){1'b0}}, msg_in};
    end

    inverter #(
        .WIDTH(WIDTH)
    ) i_inst (
        .p(p),
        .q(q),
        .clk(clk),
        .reset(reset),
        .finish(inverter_finish_internal),
        .e(e_key),
        .d(d_key)
    );

    mod_exp #(
        .WIDTH(WIDTH) // Truy?n WIDTH c?a control xu?ng cho mod_exp
                      // Bên trong mod_exp, các toán h?ng base, modulo, exponent, result s? là WIDTH*2
    ) m_inst (
        .base(msg_reg_for_modexp),    // Là WIDTH*2 bit
        .modulo(mod_reg_for_modexp),  // Là WIDTH*2 bit
        .exponent(exp_reg_for_modexp),// Là WIDTH*2 bit
        .clk(clk),
        .reset(reset1),
        .finish(mod_exp_finish),
        .result(msg_out)              // Là WIDTH*2 bit
    );
endmodule
