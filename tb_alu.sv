`timescale 1ns/1ps

`include "alu.sv"

module tb_alu;
    reg [4:0] opcode;
    reg [63:0] PC, rd_data, rs_data, rt_data, r31_data;
    reg [11:0] L_data;
    wire [63:0] result;
    wire writeback;
    wire [63:0] branch_target;
    wire branch_taken;

    integer pass_count, fail_count;

    ALU uut(
        .opcode(opcode),
        .PC(PC),
        .rd_data(rd_data),
        .rs_data(rs_data),
        .rt_data(rt_data),
        .r31_data(r31_data),
        .L_data(L_data),
        .result(result),
        .writeback(writeback),
        .branch_target(branch_target),
        .branch_taken(branch_taken)
    );

    task check_result(input [63:0] expected, input [255:0] name);
        begin
            if (result === expected) begin
                $display("  PASS %0s: result = 0x%h", name, result);
                pass_count = pass_count + 1;
            end else begin
                $display("  FAIL %0s: got 0x%h, expected 0x%h", name, result, expected);
                fail_count = fail_count + 1;
            end
        end
    endtask

    task check_branch(input [63:0] exp_target, input exp_taken, input [255:0] name);
        begin
            if (branch_target === exp_target && branch_taken === exp_taken) begin
                $display("  PASS %0s: target=0x%h, taken=%b", name, branch_target, branch_taken);
                pass_count = pass_count + 1;
            end else begin
                $display("  FAIL %0s: target=0x%h (exp 0x%h), taken=%b (exp %b)",
                         name, branch_target, exp_target, branch_taken, exp_taken);
                fail_count = fail_count + 1;
            end
        end
    endtask

    initial begin
        pass_count = 0;
        fail_count = 0;
        PC = 64'h2000;
        rd_data = 0; rs_data = 0; rt_data = 0; r31_data = 64'h80000; L_data = 0;

        // ===================== INTEGER ARITHMETIC =====================
        $display("\n=== INTEGER ARITHMETIC ===");

        // ADD (0x18): rd = rs + rt
        opcode = 5'h18; rs_data = 64'd10; rt_data = 64'd20; #10;
        check_result(64'd30, "ADD 10+20=30");

        // ADDI (0x19): rd = rd + sext(L)
        opcode = 5'h19; rd_data = 64'd100; L_data = 12'd50; #10;
        check_result(64'd150, "ADDI 100+50=150");

        // ADDI with negative L
        opcode = 5'h19; rd_data = 64'd100; L_data = 12'hFF6; #10; // -10
        check_result(64'd90, "ADDI 100+(-10)=90");

        // SUB (0x1a): rd = rs - rt
        opcode = 5'h1a; rs_data = 64'd30; rt_data = 64'd10; #10;
        check_result(64'd20, "SUB 30-10=20");

        // SUBI (0x1b): rd = rd - sext(L)
        opcode = 5'h1b; rd_data = 64'd100; L_data = 12'd30; #10;
        check_result(64'd70, "SUBI 100-30=70");

        // MUL (0x1c): rd = rs * rt
        opcode = 5'h1c; rs_data = 64'd7; rt_data = 64'd8; #10;
        check_result(64'd56, "MUL 7*8=56");

        // DIV (0x1d): rd = rs / rt
        opcode = 5'h1d; rs_data = 64'd100; rt_data = 64'd10; #10;
        check_result(64'd10, "DIV 100/10=10");

        // ===================== LOGIC =====================
        $display("\n=== LOGIC ===");

        // AND (0x00)
        opcode = 5'h00; rs_data = 64'hFF00FF00; rt_data = 64'hF0F0F0F0; #10;
        check_result(64'hF000F000, "AND");

        // OR (0x01)
        opcode = 5'h01; rs_data = 64'hFF00FF00; rt_data = 64'hF0F0F0F0; #10;
        check_result(64'hFFF0FFF0, "OR");

        // XOR (0x02)
        opcode = 5'h02; rs_data = 64'hFF00FF00; rt_data = 64'hF0F0F0F0; #10;
        check_result(64'h0FF00FF0, "XOR");

        // NOT (0x03)
        opcode = 5'h03; rs_data = 64'h00000000000000FF; #10;
        check_result(64'hFFFFFFFFFFFFFF00, "NOT");

        // ===================== SHIFTS =====================
        $display("\n=== SHIFTS ===");

        // SHFTR (0x04)
        opcode = 5'h04; rs_data = 64'h80; rt_data = 64'd3; #10;
        check_result(64'h10, "SHFTR 0x80>>3=0x10");

        // SHFTRI (0x05)
        opcode = 5'h05; rd_data = 64'h80; L_data = 12'd3; #10;
        check_result(64'h10, "SHFTRI 0x80>>3=0x10");

        // SHFTL (0x06)
        opcode = 5'h06; rs_data = 64'h1; rt_data = 64'd8; #10;
        check_result(64'h100, "SHFTL 1<<8=0x100");

        // SHFTLI (0x07)
        opcode = 5'h07; rd_data = 64'h1; L_data = 12'd8; #10;
        check_result(64'h100, "SHFTLI 1<<8=0x100");

        // ===================== BRANCHES =====================
        $display("\n=== BRANCHES ===");

        // BR rd (0x08)
        opcode = 5'h08; rd_data = 64'h3000; #10;
        check_branch(64'h3000, 1'b1, "BR rd=0x3000");

        // BRR rd (0x09)
        opcode = 5'h09; rd_data = 64'h100; PC = 64'h2000; #10;
        check_branch(64'h2100, 1'b1, "BRR rd=0x100, PC+rd=0x2100");

        // BRR L (0x0a)
        opcode = 5'h0a; L_data = 12'd16; PC = 64'h2000; #10;
        check_branch(64'h2010, 1'b1, "BRR L=16, PC+16=0x2010");

        // BRR L negative
        opcode = 5'h0a; L_data = 12'hFF0; PC = 64'h2000; #10; // -16
        check_branch(64'h1FF0, 1'b1, "BRR L=-16, PC-16=0x1FF0");

        // BRNZ (0x0b) - taken (rs != 0)
        opcode = 5'h0b; rd_data = 64'h4000; rs_data = 64'd1; #10;
        check_branch(64'h4000, 1'b1, "BRNZ taken (rs=1)");

        // BRNZ - not taken (rs == 0)
        opcode = 5'h0b; rd_data = 64'h4000; rs_data = 64'd0; #10;
        check_branch(64'h4000, 1'b0, "BRNZ not taken (rs=0)");

        // BRGT (0x0e) - taken (rs > rt)
        opcode = 5'h0e; rd_data = 64'h5000; rs_data = 64'd10; rt_data = 64'd5; #10;
        check_branch(64'h5000, 1'b1, "BRGT taken (10>5)");

        // BRGT - not taken (rs <= rt)
        opcode = 5'h0e; rd_data = 64'h5000; rs_data = 64'd3; rt_data = 64'd10; #10;
        check_branch(64'h5000, 1'b0, "BRGT not taken (3<=10)");

        // ===================== CALL/RETURN =====================
        $display("\n=== CALL/RETURN ===");

        // CALL (0x0c)
        opcode = 5'h0c; rd_data = 64'h6000; r31_data = 64'h80000; PC = 64'h2000; #10;
        check_result(64'h7FFF8, "CALL: r31-8 = 0x7FFF8");
        check_branch(64'h6000, 1'b1, "CALL: branch to rd");

        // RETURN (0x0d)
        opcode = 5'h0d; r31_data = 64'h7FFF8; #10;
        check_result(64'h80000, "RETURN: r31+8 = 0x80000");

        // ===================== MOV =====================
        $display("\n=== MOV ===");

        // MOV rd, (rs)(L) - load address calc (0x10)
        opcode = 5'h10; rs_data = 64'h1000; L_data = 12'd8; #10;
        check_result(64'h1008, "MOV load addr: rs+L = 0x1008");

        // MOV rd, rs (0x11)
        opcode = 5'h11; rs_data = 64'hDEADBEEF; #10;
        check_result(64'hDEADBEEF, "MOV rd=rs");

        // MOV rd, L (0x12) - sets low 12 bits via sign extension
        opcode = 5'h12; L_data = 12'hABC; #10;
        check_result(64'hFFFFFFFFFFFFFABC, "MOV rd, L=0xABC (sign-extended)");

        // MOV (rd)(L), rs - store address calc (0x13)
        opcode = 5'h13; rd_data = 64'h2000; L_data = 12'd16; #10;
        check_result(64'h2010, "MOV store addr: rd+L = 0x2010");

        // ===================== FPU (via ALU) =====================
        $display("\n=== FPU VIA ALU ===");

        // FADD (0x14): 1.0 + 2.0 = 3.0
        opcode = 5'h14; rs_data = 64'h3FF0000000000000; rt_data = 64'h4000000000000000; #10;
        check_result(64'h4008000000000000, "FADD 1.0+2.0=3.0");

        // FSUB (0x15): 5.0 - 3.0 = 2.0
        opcode = 5'h15; rs_data = 64'h4014000000000000; rt_data = 64'h4008000000000000; #10;
        check_result(64'h4000000000000000, "FSUB 5.0-3.0=2.0");

        // FMUL (0x16): 3.0 * 4.0 = 12.0
        opcode = 5'h16; rs_data = 64'h4008000000000000; rt_data = 64'h4010000000000000; #10;
        check_result(64'h4028000000000000, "FMUL 3.0*4.0=12.0");

        // FDIV (0x17): 10.0 / 2.0 = 5.0
        opcode = 5'h17; rs_data = 64'h4024000000000000; rt_data = 64'h4000000000000000; #10;
        check_result(64'h4014000000000000, "FDIV 10.0/2.0=5.0");

        // ===================== SUMMARY =====================
        $display("\n============================================");
        $display("  ALU RESULTS: %0d passed, %0d failed out of %0d tests",
                 pass_count, fail_count, pass_count + fail_count);
        $display("============================================");
        $finish;
    end
endmodule
