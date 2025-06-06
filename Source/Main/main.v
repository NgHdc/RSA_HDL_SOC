`timescale 1ns / 1ps

/*to calculate decryption key 'd' and encryption key 'e' we use extended euclidian algorithm
i.e             d * e = 1 mod (phi)
*/

module control #(
    parameter WIDTH = 32 // 1. Khai báo WIDTH ? ?ây
) (
    input [WIDTH-1:0] p, q, // 2. ?ã xóa d?u ph?y th?a sau q
    input clk,
    input reset,
    input reset1,
    input encrypt_decrypt, //if =1 it is used for encryption, otherwise decryption.
    input [WIDTH-1:0] msg_in, //msg input to be encrypted/decrypted
    output [WIDTH*2-1:0] msg_out, //output message after running the program
    output mod_exp_finish
);

    // 3. Xóa dòng "parameter WIDTH = 32;" ? ?ây

    wire inverter_finish;
    wire [WIDTH*2-1:0] e,d; //e=encryption key.d=decryption key.
    wire [WIDTH*2-1:0] exponent = encrypt_decrypt ? e : d;
    wire [WIDTH*2-1:0] modulo = p * q; // p, q là [WIDTH-1:0] -> modulo là [WIDTH*2-1:0]
    wire mod_exp_reset  = 1'b0; // Dây này ???c khai báo nh?ng không ???c s? d?ng trong logic k?t n?i reset

    reg [WIDTH*2-1:0] exp_reg, msg_reg;
    reg [WIDTH*2-1:0] mod_reg;

    always @(posedge clk) begin
        exp_reg <= exponent;
        mod_reg <= modulo;
        msg_reg <= {{(WIDTH){1'b0}}, msg_in}; // msg_in [WIDTH-1:0] ???c m? r?ng bit 0 khi gán cho msg_reg [WIDTH*2-1:0]
    end

    // S? d?ng cách truy?n tham s? hi?n ??i h?n khi kh?i t?o module con (khuy?n ngh?)
    inverter #(
        .WIDTH(WIDTH)
    ) i_inst ( // ??i tên instance ?? rõ ràng h?n
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
                      // Các c?ng c?a mod_exp là [WIDTH*2-1:0], nên có th? parameter c?a nó là WIDTH*2.
                      // Tuy nhiên, n?u logic bên trong mod_exp ???c vi?t theo WIDTH (và nhân 2 bên trong),
                      // thì truy?n WIDTH là ?úng. D?a trên các s?a l?i tr??c, mod_exp nh?n WIDTH.
    ) m_inst ( // ??i tên instance
        .base(msg_reg),        // Gi? s? c?ng ??u tiên c?a mod_exp là 'base'
        .modulo(mod_reg),      // C?ng th? hai là 'modulo'
        .exponent(exp_reg),    // C?ng th? ba là 'exponent'
        .clk(clk),
        .reset(reset1),        // mod_exp s? d?ng reset1
        .finish(mod_exp_finish),
        .result(msg_out)
    );

    // Ho?c gi? nguyên cách dùng defparam n?u b?n mu?n (nh?ng c?n tên instance ?úng)
    // inverter i(p,q,clk,reset,inverter_finish,e,d);
    // defparam i.WIDTH = WIDTH;
    // mod_exp m(msg_reg,mod_reg,exp_reg,clk,reset1,mod_exp_finish,msg_out);
    // defparam m.WIDTH = WIDTH;

endmodule
