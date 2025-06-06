`timescale 1ns / 1ps
`define UPDATE 2'd1
`define HOLD 2'd2

/* to calculate *** a^b mod n *** we use right to left binary exponentiation (by .BRUCE SCHIENER) */
module mod_exp#(parameter WIDTH = 32) // <-- Declare WIDTH here, inside the parentheses
(
    input [WIDTH*2-1:0] base, // base here represents (a) 
    input [WIDTH*2-1:0] modulo, // modulo here is modulus (n)
    input [WIDTH*2-1:0] exponent, // exponent here is the power of base (b)
    input clk, // system clk
    input reset, // resets module
    output finish, // sends finish signal on completion
    output [WIDTH*2-1:0] result
);
    // Remove the 'parameter WIDTH = 32;' line from here, as it's now in the header
        
    reg [WIDTH*2-1:0] base_reg,modulo_reg,exponent_reg,result_reg;
    reg [1:0] state;
    
    wire [WIDTH*2-1:0] result_mul_base = result_reg * base_reg;
    wire [WIDTH*2-1:0] result_next;
    wire [WIDTH*2-1:0] base_squared = base_reg * base_reg;
    wire [WIDTH*2-1:0] base_next;
    wire [WIDTH*2-1:0] exponent_next = exponent_reg >> 1;
    
    assign finish = (state == `HOLD) ? 1'b1:1'b0;
    assign result = result_reg;
    
    // Placeholder wires for the 'Q' output of the 'mod' module
    wire [WIDTH*2-1:0] dummy_q_bs; 
    wire [WIDTH*2-1:0] dummy_q_rmb; 

    // Instantiate 'mod' module for base_squared_mod
    mod base_squared_mod(
        .a(base_squared),
        .n(modulo_reg),
        .R(base_next),
        .Q(dummy_q_bs) // Connected to a dummy wire as 'Q' is an output of 'mod'
    );
    // Parameters for instantiated modules are typically set with 'defparam' or by passing in the instance
    defparam base_squared_mod.WIDTH = WIDTH*2; 
                                    
    // Instantiate 'mod' module for result_mul_base_mod
    mod result_mul_base_mod (
        .a(result_mul_base),
        .n(modulo_reg),
        .R(result_next),
        .Q(dummy_q_rmb) // Connected to a dummy wire
    );
    defparam result_mul_base_mod.WIDTH = WIDTH*2; 
    
    
    always @(posedge clk) begin
        if(reset) begin                                                            
            base_reg <= base;
            modulo_reg <= modulo;
            exponent_reg <= exponent;          
            result_reg <= {{((WIDTH*2)-1){1'b0}}, 1'b1}; // Correctly initialize to 1 with WIDTH*2 bits
            state <= `UPDATE;
        end
        else case(state)
            `UPDATE: begin
                if (exponent_reg != {{(WIDTH*2){1'b0}}}) begin // Check against zero for the full width
                    if (exponent_reg[0]) begin
                        result_reg <= result_next;
                    end
                    base_reg <= base_next;
                    exponent_reg <= exponent_next;
                    state <= `UPDATE;
                end
                else begin
                    state <= `HOLD;
                end
            end
            
            `HOLD: begin
                // No action needed here, module holds its state
            end
        endcase
    end
endmodule
