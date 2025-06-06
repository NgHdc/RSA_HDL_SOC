`timescale 1ns / 1ps

/*to calculate decryption key 'd' and encryption key 'e' we use extended euclidian algorithm
i.e             d * e = 1 mod (phi)
*/

module control #(
    parameter WIDTH = 32 // 1. Khai b�o WIDTH ? ?�y
) (
    input [WIDTH-1:0] p, q, // 2. ?� x�a d?u ph?y th?a sau q
    input clk,
    input reset,
    input reset1,
    input encrypt_decrypt, //if =1 it is used for encryption, otherwise decryption.
    input [WIDTH-1:0] msg_in, //msg input to be encrypted/decrypted
    output [WIDTH*2-1:0] msg_out, //output message after running the program
    output mod_exp_finish
);

    // 3. X�a d�ng "parameter WIDTH = 32;" ? ?�y

    wire inverter_finish;
    wire [WIDTH*2-1:0] e,d; //e=encryption key.d=decryption key.
    wire [WIDTH*2-1:0] exponent = encrypt_decrypt ? e : d;
    wire [WIDTH*2-1:0] modulo = p * q; // p, q l� [WIDTH-1:0] -> modulo l� [WIDTH*2-1:0]
    wire mod_exp_reset  = 1'b0; // D�y n�y ???c khai b�o nh?ng kh�ng ???c s? d?ng trong logic k?t n?i reset

    reg [WIDTH*2-1:0] exp_reg, msg_reg;
    reg [WIDTH*2-1:0] mod_reg;

    always @(posedge clk) begin
        exp_reg <= exponent;
        mod_reg <= modulo;
        msg_reg <= {{(WIDTH){1'b0}}, msg_in}; // msg_in [WIDTH-1:0] ???c m? r?ng bit 0 khi g�n cho msg_reg [WIDTH*2-1:0]
    end

    // S? d?ng c�ch truy?n tham s? hi?n ??i h?n khi kh?i t?o module con (khuy?n ngh?)
    inverter #(
        .WIDTH(WIDTH)
    ) i_inst ( // ??i t�n instance ?? r� r�ng h?n
        .p(p),
        .q(q),
        .clk(clk),
        .reset(reset),
        .finish(inverter_finish),
        .e(e),
        .d(d)
    );

    mod_exp #(
        .WIDTH(WIDTH) // mod_exp c?n WIDTH hay WIDTH*2? Ki?m tra l?i module mod_exp.
                      // C�c c?ng c?a mod_exp l� [WIDTH*2-1:0], n�n c� th? parameter c?a n� l� WIDTH*2.
                      // Tuy nhi�n, n?u logic b�n trong mod_exp ???c vi?t theo WIDTH (v� nh�n 2 b�n trong),
                      // th� truy?n WIDTH l� ?�ng. D?a tr�n c�c s?a l?i tr??c, mod_exp nh?n WIDTH.
    ) m_inst ( // ??i t�n instance
        .base(msg_reg),        // Gi? s? c?ng ??u ti�n c?a mod_exp l� 'base'
        .modulo(mod_reg),      // C?ng th? hai l� 'modulo'
        .exponent(exp_reg),    // C?ng th? ba l� 'exponent'
        .clk(clk),
        .reset(reset1),        // mod_exp s? d?ng reset1
        .finish(mod_exp_finish),
        .result(msg_out)
    );

    // Ho?c gi? nguy�n c�ch d�ng defparam n?u b?n mu?n (nh?ng c?n t�n instance ?�ng)
    // inverter i(p,q,clk,reset,inverter_finish,e,d);
    // defparam i.WIDTH = WIDTH;
    // mod_exp m(msg_reg,mod_reg,exp_reg,clk,reset1,mod_exp_finish,msg_out);
    // defparam m.WIDTH = WIDTH;

endmodule
