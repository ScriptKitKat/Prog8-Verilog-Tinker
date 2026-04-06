`timescale 1ns/1ps

`include "tinker.sv"

module tb_tinker;
    reg clk, reset;
    integer pass_count, fail_count;

    tinker_core uut(.clk(clk), .reset(reset));

    always #5 clk = ~clk;

    // Encoding: [31:27]=opcode, [26:22]=rd, [21:17]=rs, [16:12]=rt, [11:0]=L
    function [31:0] encode;
        input [4:0] op;
        input [4:0] rd;
        input [4:0] rs;
        input [4:0] rt;
        input [11:0] lit;
        encode = {op, rd, rs, rt, lit};
    endfunction

    // Write a 32-bit instruction to memory at byte address addr (little-endian)
    task write_instr(input [63:0] addr, input [31:0] instr);
        begin
            uut.memory.bytes[addr]     = instr[7:0];
            uut.memory.bytes[addr + 1] = instr[15:8];
            uut.memory.bytes[addr + 2] = instr[23:16];
            uut.memory.bytes[addr + 3] = instr[31:24];
        end
    endtask

    // Write a 64-bit value to memory at byte address addr (little-endian)
    task write_mem64(input [63:0] addr, input [63:0] val);
        begin
            uut.memory.bytes[addr]     = val[7:0];
            uut.memory.bytes[addr + 1] = val[15:8];
            uut.memory.bytes[addr + 2] = val[23:16];
            uut.memory.bytes[addr + 3] = val[31:24];
            uut.memory.bytes[addr + 4] = val[39:32];
            uut.memory.bytes[addr + 5] = val[47:40];
            uut.memory.bytes[addr + 6] = val[55:48];
            uut.memory.bytes[addr + 7] = val[63:56];
        end
    endtask

    task check_reg(input [4:0] reg_num, input [63:0] expected, input [255:0] name);
        begin
            if (uut.reg_file.registers[reg_num] === expected) begin
                $display("  PASS [%0d] %0s: r%0d = 0x%h", pass_count+fail_count+1, name, reg_num, expected);
                pass_count = pass_count + 1;
            end else begin
                $display("  FAIL [%0d] %0s: r%0d = 0x%h, expected 0x%h",
                         pass_count+fail_count+1, name, reg_num,
                         uut.reg_file.registers[reg_num], expected);
                fail_count = fail_count + 1;
            end
        end
    endtask

    task check_pc(input [63:0] expected, input [255:0] name);
        begin
            if (uut.PC === expected) begin
                $display("  PASS [%0d] %0s: PC = 0x%h", pass_count+fail_count+1, name, expected);
                pass_count = pass_count + 1;
            end else begin
                $display("  FAIL [%0d] %0s: PC = 0x%h, expected 0x%h",
                         pass_count+fail_count+1, name, uut.PC, expected);
                fail_count = fail_count + 1;
            end
        end
    endtask

    task run_cycles(input integer n);
        integer j;
        begin
            for (j = 0; j < n; j = j + 1) @(posedge clk);
            #1;
        end
    endtask

    task do_reset;
        begin
            reset = 1;
            @(posedge clk); #1;
            reset = 0;
        end
    endtask

    initial begin
        $dumpfile("tb_tinker.vcd");
        $dumpvars(0, tb_tinker);
        clk = 0;
        pass_count = 0;
        fail_count = 0;

        // ===================== TEST 1: ADDI =====================
        $display("\n=== TEST GROUP 1: ADDI ===");
        do_reset;
        // addi r1, 10     →  r1 = r1 + 10 = 10
        write_instr(64'h2000, encode(5'h19, 5'd1, 5'd0, 5'd0, 12'd10));
        // addi r2, 20     →  r2 = r2 + 20 = 20
        write_instr(64'h2004, encode(5'h19, 5'd2, 5'd0, 5'd0, 12'd20));
        // addi r3, -5     →  r3 = r3 + (-5) = -5
        write_instr(64'h2008, encode(5'h19, 5'd3, 5'd0, 5'd0, 12'hFFB));

        run_cycles(3);
        check_reg(5'd1, 64'h0000000000000000A, "ADDI r1, 10");
        check_reg(5'd2, 64'h00000000000000014, "ADDI r2, 20");
        check_reg(5'd3, 64'hFFFFFFFFFFFFFFFB, "ADDI r3, -5");

        // ===================== TEST 2: Arithmetic =====================
        $display("\n=== TEST GROUP 2: Arithmetic ===");
        do_reset;
        // r1 = 10, r2 = 5
        write_instr(64'h2000, encode(5'h19, 5'd1, 5'd0, 5'd0, 12'd10));
        write_instr(64'h2004, encode(5'h19, 5'd2, 5'd0, 5'd0, 12'd5));
        // r3 = r1 + r2 (ADD)
        write_instr(64'h2008, encode(5'h18, 5'd3, 5'd1, 5'd2, 12'd0));
        // r4 = r1 - r2 (SUB)
        write_instr(64'h200C, encode(5'h1a, 5'd4, 5'd1, 5'd2, 12'd0));
        // r5 = r1 * r2 (MUL)
        write_instr(64'h2010, encode(5'h1c, 5'd5, 5'd1, 5'd2, 12'd0));
        // r6 = r1 / r2 (DIV)
        write_instr(64'h2014, encode(5'h1d, 5'd6, 5'd1, 5'd2, 12'd0));

        run_cycles(6);
        check_reg(5'd3, 64'd15, "ADD r1+r2=15");
        check_reg(5'd4, 64'd5,  "SUB r1-r2=5");
        check_reg(5'd5, 64'd50, "MUL r1*r2=50");
        check_reg(5'd6, 64'd2,  "DIV r1/r2=2");

        // ===================== TEST 3: Logic =====================
        $display("\n=== TEST GROUP 3: Logic ===");
        do_reset;
        // r1 = 0xFF, r2 = 0xF0
        write_instr(64'h2000, encode(5'h19, 5'd1, 5'd0, 5'd0, 12'h0FF));
        write_instr(64'h2004, encode(5'h19, 5'd2, 5'd0, 5'd0, 12'h0F0));
        // AND
        write_instr(64'h2008, encode(5'h00, 5'd3, 5'd1, 5'd2, 12'd0));
        // OR
        write_instr(64'h200C, encode(5'h01, 5'd4, 5'd1, 5'd2, 12'd0));
        // XOR
        write_instr(64'h2010, encode(5'h02, 5'd5, 5'd1, 5'd2, 12'd0));
        // NOT r1
        write_instr(64'h2014, encode(5'h03, 5'd6, 5'd1, 5'd0, 12'd0));

        run_cycles(6);
        check_reg(5'd3, 64'h0F0, "AND 0xFF & 0xF0 = 0xF0");
        check_reg(5'd4, 64'h0FF, "OR  0xFF | 0xF0 = 0xFF");
        check_reg(5'd5, 64'h00F, "XOR 0xFF ^ 0xF0 = 0x0F");
        check_reg(5'd6, 64'hFFFFFFFFFFFFFF00, "NOT ~0xFF");

        // ===================== TEST 4: Shifts =====================
        $display("\n=== TEST GROUP 4: Shifts ===");
        do_reset;
        // r1 = 0x100
        write_instr(64'h2000, encode(5'h19, 5'd1, 5'd0, 5'd0, 12'h100));
        // r2 = 4
        write_instr(64'h2004, encode(5'h19, 5'd2, 5'd0, 5'd0, 12'd4));
        // SHFTR r3 = r1 >> r2
        write_instr(64'h2008, encode(5'h04, 5'd3, 5'd1, 5'd2, 12'd0));
        // SHFTL r4 = r1 << r2
        write_instr(64'h200C, encode(5'h06, 5'd4, 5'd1, 5'd2, 12'd0));
        // SHFTRI r5 = r1 >> 4
        write_instr(64'h2010, encode(5'h05, 5'd1, 5'd0, 5'd0, 12'd4));  // rd=r1
        // Note: SHFTRI uses rd, so after this r1 = r1 >> 4 (but we check r5 below differently)
        // Let's redo: r5 starts at 0x100 via addi, then shftri r5 by 2
        write_instr(64'h2010, encode(5'h19, 5'd5, 5'd0, 5'd0, 12'h100)); // r5 = 0x100
        write_instr(64'h2014, encode(5'h05, 5'd5, 5'd0, 5'd0, 12'd2));   // r5 = r5 >> 2

        run_cycles(6);
        check_reg(5'd3, 64'h10,   "SHFTR 0x100>>4 = 0x10");
        check_reg(5'd4, 64'h1000, "SHFTL 0x100<<4 = 0x1000");
        check_reg(5'd5, 64'h40,   "SHFTRI 0x100>>2 = 0x40");

        // ===================== TEST 5: MOV rd, rs =====================
        $display("\n=== TEST GROUP 5: MOV rd, rs ===");
        do_reset;
        write_instr(64'h2000, encode(5'h19, 5'd1, 5'd0, 5'd0, 12'd42));  // r1 = 42
        write_instr(64'h2004, encode(5'h11, 5'd2, 5'd1, 5'd0, 12'd0));   // mov r2, r1

        run_cycles(2);
        check_reg(5'd2, 64'd42, "MOV r2 = r1 = 42");

        // ===================== TEST 6: Store and Load =====================
        $display("\n=== TEST GROUP 6: Store/Load ===");
        do_reset;
        // r1 = 0x100 (address), r2 = 0xAD (value to store)
        write_instr(64'h2000, encode(5'h19, 5'd1, 5'd0, 5'd0, 12'h100)); // r1 = 0x100
        write_instr(64'h2004, encode(5'h19, 5'd2, 5'd0, 5'd0, 12'hAD));  // r2 = 0xAD
        // mov (r1)(0), r2  →  mem[r1+0] = r2
        write_instr(64'h2008, encode(5'h13, 5'd1, 5'd2, 5'd0, 12'd0));
        // mov r3, (r1)(0)  →  r3 = mem[r1+0]
        write_instr(64'h200C, encode(5'h10, 5'd3, 5'd1, 5'd0, 12'd0));

        run_cycles(4);
        check_reg(5'd3, 64'hAD, "Load r3 from mem[r1] = 0xAD");

        // ===================== TEST 7: BR rd =====================
        $display("\n=== TEST GROUP 7: BR rd ===");
        do_reset;
        // r1 = 0x2010 (branch target)
        write_instr(64'h2000, encode(5'h19, 5'd1, 5'd0, 5'd0, 12'h010)); // r1 = 0x10
        // We need r1 = 0x2010: addi r1, 0x10 then shftli... too complex.
        // Simpler: set r1 = some small addr, branch there, check we skip instructions
        // r1 = 0x200C = skip 2 instructions (branch from 0x2004 to 0x200C)
        // Actually the literal only gives 12 bits. Let's use BRR L instead for this.
        // Instead: write target addr in memory and load it.
        // Simplest: branch relative by L
        // BRR L = 8 → skip next instruction (from 0x2000, go to 0x2008)
        write_instr(64'h2000, encode(5'h0a, 5'd0, 5'd0, 5'd0, 12'd8)); // brr 8
        write_instr(64'h2004, encode(5'h19, 5'd2, 5'd0, 5'd0, 12'd99)); // skipped: r2 = 99
        write_instr(64'h2008, encode(5'h19, 5'd3, 5'd0, 5'd0, 12'd77)); // r3 = 77

        run_cycles(2);
        check_reg(5'd2, 64'd0,  "Skipped instruction (r2 should be 0)");

        // ===================== TEST 8: BRNZ =====================
        $display("\n=== TEST GROUP 8: BRNZ ===");
        do_reset;
        // r1 = 0 (condition false), branch should NOT be taken
        write_instr(64'h2000, encode(5'h19, 5'd1, 5'd0, 5'd0, 12'd0));   // r1 = 0
        // We need rd = branch target. Use r2 for target.
        // Set r2 to some address using addi (small value, but that's ok for testing)
        write_instr(64'h2004, encode(5'h19, 5'd2, 5'd0, 5'd0, 12'h100)); // r2 = 0x100
        // brnz r2, r1 → branch to r2 if r1 != 0 (should NOT branch)
        write_instr(64'h2008, encode(5'h0b, 5'd2, 5'd1, 5'd0, 12'd0));
        // next instr should execute
        write_instr(64'h200C, encode(5'h19, 5'd4, 5'd0, 5'd0, 12'd55)); // r4 = 55

        run_cycles(4);
        check_reg(5'd4, 64'd55, "BRNZ not taken, next instr runs (r4=55)");

        // ===================== TEST 9: BRGT =====================
        $display("\n=== TEST GROUP 9: BRGT ===");
        do_reset;
        // r1 = 3, r2 = 10, r3 = 0x100
        write_instr(64'h2000, encode(5'h19, 5'd1, 5'd0, 5'd0, 12'd3));
        write_instr(64'h2004, encode(5'h19, 5'd2, 5'd0, 5'd0, 12'd10));
        write_instr(64'h2008, encode(5'h19, 5'd3, 5'd0, 5'd0, 12'h100));
        // brgt r3, r1, r2 → branch to r3 if r1 > r2 (3 > 10 is false)
        write_instr(64'h200C, encode(5'h0e, 5'd3, 5'd1, 5'd2, 12'd0));
        // should execute next
        write_instr(64'h2010, encode(5'h19, 5'd5, 5'd0, 5'd0, 12'd88));

        run_cycles(5);
        check_reg(5'd5, 64'd88, "BRGT not taken (3<=10), r5=88");

        // ===================== TEST 10: SUBI =====================
        $display("\n=== TEST GROUP 10: SUBI ===");
        do_reset;
        write_instr(64'h2000, encode(5'h19, 5'd1, 5'd0, 5'd0, 12'd100)); // r1 = 100
        write_instr(64'h2004, encode(5'h1b, 5'd1, 5'd0, 5'd0, 12'd30));  // subi r1, 30

        run_cycles(2);
        check_reg(5'd1, 64'd70, "SUBI 100-30=70");

        // ===================== TEST 11: r0 hardwired zero =====================
        $display("\n=== TEST GROUP 11: r0 hardwired zero ===");
        do_reset;
        write_instr(64'h2000, encode(5'h19, 5'd0, 5'd0, 5'd0, 12'd42)); // addi r0, 42

        run_cycles(1);
        check_reg(5'd0, 64'd0, "r0 stays 0 after ADDI r0, 42");

        // ===================== TEST 12: SP init =====================
        $display("\n=== TEST GROUP 12: SP init ===");
        do_reset;
        #1;
        check_reg(5'd31, 64'h80000, "r31 (SP) initialized to MEM_SIZE");

        // ===================== TEST 13: PC init =====================
        $display("\n=== TEST GROUP 13: PC init ===");
        do_reset;
        #1;
        check_pc(64'h2000, "PC starts at 0x2000 after reset");

        // ===================== TEST 14: CALL and RETURN =====================
        $display("\n=== TEST GROUP 14: CALL/RETURN ===");
        do_reset;
        // Set r1 = 0x2010 (call target) using addi
        write_instr(64'h2000, encode(5'h19, 5'd1, 5'd0, 5'd0, 12'h010)); // r1 = 0x10

        // We need r1 to be the actual target PC. Since addi only gives 12 bits,
        // let's use a nearby address. We'll put the function at 0x2010.
        // First, make r1 = 0x2010 using mov rd, L then addi
        // mov r1, L = 0x010 → r1 = 0x10 (sign-extended, but 0x010 is positive)
        // Then we need to add 0x2000. Let's use shftli + or.
        // Simpler approach: put function at address 0x10 (low memory)
        // Or: use BRR L for the function call pattern instead

        // Let's test CALL with small address
        // r1 = target address (0x30)
        write_instr(64'h2000, encode(5'h19, 5'd1, 5'd0, 5'd0, 12'h030)); // r1 = 0x30
        // CALL r1: push PC+4 to mem[r31-8], r31 = r31-8, branch to r1
        write_instr(64'h2004, encode(5'h0c, 5'd1, 5'd0, 5'd0, 12'd0));

        // At address 0x30: set r2 = 123, then return
        write_instr(64'h0030, encode(5'h19, 5'd2, 5'd0, 5'd0, 12'd123));
        write_instr(64'h0034, encode(5'h0d, 5'd0, 5'd0, 5'd0, 12'd0));  // return

        // After return, should continue at 0x2008
        write_instr(64'h2008, encode(5'h19, 5'd3, 5'd0, 5'd0, 12'd77)); // r3 = 77

        run_cycles(5);
        check_reg(5'd2, 64'd123, "CALL: function set r2=123");
        check_reg(5'd3, 64'd77,  "RETURN: continued at r3=77");

        // ===================== TEST 15: MOV rd, L (set low 12 bits) =====================
        $display("\n=== TEST GROUP 16: MOV rd, L ===");
        do_reset;
        // First set r1 to something with high bits
        write_instr(64'h2000, encode(5'h19, 5'd1, 5'd0, 5'd0, 12'h7FF)); // r1 = 0x7FF (sext = 0x7FF)
        // Now mov r1, L = 0x123 → r1[63:12] stays, r1[11:0] = 0x123
        write_instr(64'h2004, encode(5'h12, 5'd1, 5'd0, 5'd0, 12'h123));

        run_cycles(2);
        // r1 was 0x7FF, mov L replaces low 12: result = {0x7FF[63:12], 0x123} = {0x0, 0x123}
        // Actually writeback_data for 0x12 = {rd_data[63:12], L}
        // rd_data = 0x7FF = 64'h00000000000007FF
        // rd_data[63:12] = 0x0000000000000 (since 0x7FF only has bits in [10:0])
        // Result = {52'h0, 12'h123} = 0x123
        check_reg(5'd1, 64'h0000000000000123, "MOV rd, L: low 12 bits set to 0x123");

        // ===================== SUMMARY =====================
        $display("\n============================================");
        $display("  TINKER RESULTS: %0d passed, %0d failed out of %0d tests",
                 pass_count, fail_count, pass_count + fail_count);
        $display("============================================");
        $finish;
    end
endmodule
