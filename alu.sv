`include "fpu.sv"

module ALU(
    input         clk,
    input  [4:0]  opcode,
    input  [63:0] rd,
    input  [63:0] rs,
    input  [63:0] rt,
    input  [11:0] lit,
    output reg [63:0] out,
    output reg        writeback
);
    `include "constants.vh"

    // Sign-extend the 12-bit literal to 64 bits
    wire [63:0] extended_lit;
    assign extended_lit = {{52{lit[11]}}, lit};

    // ---- FPU sub-modules (all combinational, run in parallel) ----
    wire [63:0] fpu_add_result, fpu_sub_result, fpu_mul_result, fpu_div_result;

    fpu_add fadd_u(.a(rs), .b(rt), .result(fpu_add_result));
    fpu_mul fmul_u(.a(rs), .b(rt), .result(fpu_mul_result));
    fpu_div fdiv_u(.a(rs), .b(rt), .result(fpu_div_result));

    // FSUB = FADD with sign of rt flipped
    wire [63:0] rt_negated;
    assign rt_negated = {~rt[63], rt[62:0]};
    fpu_add fsub_u(.a(rs), .b(rt_negated), .result(fpu_sub_result));

    always @(*) begin
        out = 64'b0;
        writeback = 1'b0;

        case (opcode)
            // ---- Integer arithmetic ----
            ADD:  begin out = rs + rt;              writeback = 1'b1; end
            ADDI: begin out = rd + extended_lit;    writeback = 1'b1; end
            SUB:  begin out = rs - rt;              writeback = 1'b1; end
            SUBI: begin out = rd - extended_lit;    writeback = 1'b1; end
            MUL:  begin out = rs * rt;              writeback = 1'b1; end
            DIV:  begin out = rs / rt;              writeback = 1'b1; end

            // ---- Logic ----
            AND:  begin out = rs & rt;              writeback = 1'b1; end
            OR:   begin out = rs | rt;              writeback = 1'b1; end
            XOR:  begin out = rs ^ rt;              writeback = 1'b1; end
            NOT:  begin out = ~rs;                  writeback = 1'b1; end

            // ---- Shifts ----
            SHFTR:  begin out = rs >> rt;           writeback = 1'b1; end
            SHFTRI: begin out = rd >> extended_lit; writeback = 1'b1; end
            SHFTL:  begin out = rs << rt;           writeback = 1'b1; end
            SHFTLI: begin out = rd << extended_lit; writeback = 1'b1; end

            // ---- Branches ----
            BR:    begin out = rd;                  writeback = 1'b0; end
            BRR_R: begin out = rd;                  writeback = 1'b0; end
            BRR_L: begin out = extended_lit;        writeback = 1'b0; end
            BRNZ:  begin out = rd;                  writeback = 1'b0; end
            CALL:  begin out = rd;                  writeback = 1'b0; end
            RET:   begin out = 64'b0;               writeback = 1'b0; end
            BRGT:  begin out = rd;                  writeback = 1'b0; end

            // ---- MOV operations ----
            MOV_LD: begin out = rs + extended_lit;  writeback = 1'b1; end
            MOV_RR: begin out = rs;                 writeback = 1'b1; end
            MOV_UP: begin out = extended_lit;        writeback = 1'b1; end
            MOV_ST: begin out = rd + extended_lit;  writeback = 1'b0; end

            // ---- Floating-point ----
            ADDF: begin out = fpu_add_result;       writeback = 1'b1; end
            SUBF: begin out = fpu_sub_result;       writeback = 1'b1; end
            MULF: begin out = fpu_mul_result;       writeback = 1'b1; end
            DIVF: begin out = fpu_div_result;       writeback = 1'b1; end

            default: begin out = 64'b0;             writeback = 1'b0; end
        endcase
    end
endmodule