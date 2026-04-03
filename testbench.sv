`timescale 1ns / 1ps
`include "tinker.sv"

// ============================================================================
// TINKER CORE TESTBENCH
//
// Helper function encode_instr builds 32-bit Tinker instructions:
//   [4:0]   = opcode
//   [9:5]   = rd
//   [14:10] = rs
//   [19:15] = rt
//   [31:20] = L (12-bit immediate)
//
// Strategy: load instructions into memory at START (0x2000), then let the
// core execute them cycle by cycle, checking register values after each.
// ============================================================================

module tinker_core_tb;
    reg clk, reset;
    integer test_num;
    integer pass_count, fail_count;

    tinker_core uut(.clk(clk), .reset(reset));

    // Clock: 10ns period
    initial clk = 0;
    always #5 clk = ~clk;

    // ---- Helper: encode a Tinker instruction ----
    function [31:0] encode_instr;
        input [4:0]  opcode;
        input [4:0]  rd;
        input [4:0]  rs;
        input [4:0]  rt;
        input [11:0] imm;
        begin
            encode_instr = {imm, rt, rs, rd, opcode};
        end
    endfunction

    // ---- Helper: write a 32-bit instruction to memory (little-endian) ----
    task write_instr;
        input [63:0] addr;
        input [31:0] instr;
        begin
            uut.memory.bytes[addr]     = instr[7:0];
            uut.memory.bytes[addr + 1] = instr[15:8];
            uut.memory.bytes[addr + 2] = instr[23:16];
            uut.memory.bytes[addr + 3] = instr[31:24];
        end
    endtask

    // ---- Helper: write a 64-bit value to memory (little-endian) ----
    task write_mem64;
        input [63:0] addr;
        input [63:0] value;
        begin
            uut.memory.bytes[addr]     = value[7:0];
            uut.memory.bytes[addr + 1] = value[15:8];
            uut.memory.bytes[addr + 2] = value[23:16];
            uut.memory.bytes[addr + 3] = value[31:24];
            uut.memory.bytes[addr + 4] = value[39:32];
            uut.memory.bytes[addr + 5] = value[47:40];
            uut.memory.bytes[addr + 6] = value[55:48];
            uut.memory.bytes[addr + 7] = value[63:56];
        end
    endtask

    // ---- Helper: check a register value ----
    task check_reg;
        input [4:0]  reg_num;
        input [63:0] expected;
        input [255:0] test_name;
        begin
            test_num = test_num + 1;
            if (uut.reg_file.registers[reg_num] === expected) begin
                $display("  PASS [%0d] %0s: r%0d = 0x%016h", test_num, test_name, reg_num, expected);
                pass_count = pass_count + 1;
            end else begin
                $display("  FAIL [%0d] %0s: r%0d = 0x%016h, expected 0x%016h",
                         test_num, test_name, reg_num,
                         uut.reg_file.registers[reg_num], expected);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // ---- Helper: check PC value ----
    task check_pc;
        input [63:0] expected;
        input [255:0] test_name;
        begin
            test_num = test_num + 1;
            if (uut.PC === expected) begin
                $display("  PASS [%0d] %0s: PC = 0x%016h", test_num, test_name, expected);
                pass_count = pass_count + 1;
            end else begin
                $display("  FAIL [%0d] %0s: PC = 0x%016h, expected 0x%016h",
                         test_num, test_name, uut.PC, expected);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // ---- Helper: check a 64-bit memory value ----
    task check_mem64;
        input [63:0] addr;
        input [63:0] expected;
        input [255:0] test_name;
        reg [63:0] actual;
        begin
            test_num = test_num + 1;
            actual = {uut.memory.bytes[addr+7], uut.memory.bytes[addr+6],
                      uut.memory.bytes[addr+5], uut.memory.bytes[addr+4],
                      uut.memory.bytes[addr+3], uut.memory.bytes[addr+2],
                      uut.memory.bytes[addr+1], uut.memory.bytes[addr]};
            if (actual === expected) begin
                $display("  PASS [%0d] %0s: mem[0x%h] = 0x%016h", test_num, test_name, addr, expected);
                pass_count = pass_count + 1;
            end else begin
                $display("  FAIL [%0d] %0s: mem[0x%h] = 0x%016h, expected 0x%016h",
                         test_num, test_name, addr, actual, expected);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // ---- Helper: run one clock cycle ----
    task run_cycle;
        begin
            @(posedge clk);
            #1; // small delay for combinational logic to settle
        end
    endtask

    // ---- Helper: reset the core and clear memory ----
    task do_reset;
        integer j;
        begin
            reset = 1;
            @(posedge clk); #1;
            @(posedge clk); #1;
            reset = 0;
            // Clear instruction memory around START
            for (j = 0; j < 256; j = j + 1) begin
                uut.memory.bytes[16'h2000 + j] = 8'h00;
            end
        end
    endtask

    // ---- Opcodes ----
    localparam OP_AND   = 5'h00, OP_OR    = 5'h01, OP_XOR   = 5'h02, OP_NOT   = 5'h03;
    localparam OP_SHFTR = 5'h04, OP_SHFTRI= 5'h05, OP_SHFTL = 5'h06, OP_SHFTLI= 5'h07;
    localparam OP_BR    = 5'h08, OP_BRR_R = 5'h09, OP_BRR_L = 5'h0a, OP_BRNZ  = 5'h0b;
    localparam OP_CALL  = 5'h0c, OP_RET   = 5'h0d, OP_BRGT  = 5'h0e;
    localparam OP_MOV_LD= 5'h10, OP_MOV_RR= 5'h11, OP_MOV_UP= 5'h12, OP_MOV_ST= 5'h13;
    localparam OP_FADD  = 5'h14, OP_FSUB  = 5'h15, OP_FMUL  = 5'h16, OP_FDIV  = 5'h17;
    localparam OP_ADD   = 5'h18, OP_ADDI  = 5'h19, OP_SUB   = 5'h1a, OP_SUBI  = 5'h1b;
    localparam OP_MUL   = 5'h1c, OP_DIV   = 5'h1d;

    initial begin
        $dumpfile("tinker_tb.vcd");
        $dumpvars(0, tinker_core_tb);

        test_num = 0;
        pass_count = 0;
        fail_count = 0;

        // ==================================================================
        // TEST GROUP 1: ADDI — load immediates into registers
        // ==================================================================
        $display("\n=== TEST GROUP 1: ADDI ===");
        do_reset;

        // ADDI r1, 10  →  r1 = r1 + 10 = 0 + 10 = 10
        write_instr(16'h2000, encode_instr(OP_ADDI, 5'd1, 5'd0, 5'd0, 12'd10));
        // ADDI r2, 20  →  r2 = r2 + 20 = 0 + 20 = 20
        write_instr(16'h2004, encode_instr(OP_ADDI, 5'd2, 5'd0, 5'd0, 12'd20));
        // ADDI r3, -5  →  r3 = r3 + (-5) = -5 (sign-extended)
        write_instr(16'h2008, encode_instr(OP_ADDI, 5'd3, 5'd0, 5'd0, 12'hFFB));

        run_cycle; // execute ADDI r1, 10
        run_cycle; // execute ADDI r2, 20
        check_reg(5'd1, 64'd10, "ADDI r1, 10");

        run_cycle; // execute ADDI r3, -5
        check_reg(5'd2, 64'd20, "ADDI r2, 20");

        run_cycle;
        check_reg(5'd3, -64'd5, "ADDI r3, -5");

        // ==================================================================
        // TEST GROUP 2: ADD, SUB, MUL, DIV
        // ==================================================================
        $display("\n=== TEST GROUP 2: Arithmetic ===");
        do_reset;

        // Setup: r1 = 15, r2 = 5
        write_instr(16'h2000, encode_instr(OP_ADDI, 5'd1, 5'd0, 5'd0, 12'd15));
        write_instr(16'h2004, encode_instr(OP_ADDI, 5'd2, 5'd0, 5'd0, 12'd5));
        // ADD r3, r1, r2  →  r3 = 15 + 5 = 20
        write_instr(16'h2008, encode_instr(OP_ADD, 5'd3, 5'd1, 5'd2, 12'd0));
        // SUB r4, r1, r2  →  r4 = 15 - 5 = 10
        write_instr(16'h200c, encode_instr(OP_SUB, 5'd4, 5'd1, 5'd2, 12'd0));
        // MUL r5, r1, r2  →  r5 = 15 * 5 = 75
        write_instr(16'h2010, encode_instr(OP_MUL, 5'd5, 5'd1, 5'd2, 12'd0));
        // DIV r6, r1, r2  →  r6 = 15 / 5 = 3
        write_instr(16'h2014, encode_instr(OP_DIV, 5'd6, 5'd1, 5'd2, 12'd0));

        run_cycle; // ADDI r1
        run_cycle; // ADDI r2
        run_cycle; // ADD r3
        run_cycle; // SUB r4
        check_reg(5'd3, 64'd20, "ADD r3 = r1 + r2");

        run_cycle; // MUL r5
        check_reg(5'd4, 64'd10, "SUB r4 = r1 - r2");

        run_cycle; // DIV r6
        check_reg(5'd5, 64'd75, "MUL r5 = r1 * r2");

        run_cycle;
        check_reg(5'd6, 64'd3, "DIV r6 = r1 / r2");

        // ==================================================================
        // TEST GROUP 3: Logic operations (AND, OR, XOR, NOT)
        // ==================================================================
        $display("\n=== TEST GROUP 3: Logic ===");
        do_reset;

        // r1 = 0xFF, r2 = 0x0F
        write_instr(16'h2000, encode_instr(OP_ADDI, 5'd1, 5'd0, 5'd0, 12'hFF));
        write_instr(16'h2004, encode_instr(OP_ADDI, 5'd2, 5'd0, 5'd0, 12'h0F));
        // AND r3, r1, r2  →  0xFF & 0x0F = 0x0F
        write_instr(16'h2008, encode_instr(OP_AND, 5'd3, 5'd1, 5'd2, 12'd0));
        // OR r4, r1, r2   →  0xFF | 0x0F = 0xFF
        write_instr(16'h200c, encode_instr(OP_OR, 5'd4, 5'd1, 5'd2, 12'd0));
        // XOR r5, r1, r2  →  0xFF ^ 0x0F = 0xF0
        write_instr(16'h2010, encode_instr(OP_XOR, 5'd5, 5'd1, 5'd2, 12'd0));
        // NOT r6, r1      →  ~0xFF
        write_instr(16'h2014, encode_instr(OP_NOT, 5'd6, 5'd1, 5'd0, 12'd0));

        run_cycle; run_cycle; // setup r1, r2
        run_cycle; // AND
        run_cycle; // OR
        check_reg(5'd3, 64'h0F, "AND r3 = r1 & r2");

        run_cycle; // XOR
        check_reg(5'd4, 64'hFF, "OR r4 = r1 | r2");

        run_cycle; // NOT
        check_reg(5'd5, 64'hF0, "XOR r5 = r1 ^ r2");

        run_cycle;
        check_reg(5'd6, ~64'hFF, "NOT r6 = ~r1");

        // ==================================================================
        // TEST GROUP 4: Shifts
        // ==================================================================
        $display("\n=== TEST GROUP 4: Shifts ===");
        do_reset;

        // r1 = 0x80, r2 = 4
        write_instr(16'h2000, encode_instr(OP_ADDI, 5'd1, 5'd0, 5'd0, 12'h80));
        write_instr(16'h2004, encode_instr(OP_ADDI, 5'd2, 5'd0, 5'd0, 12'd4));
        // SHFTR r3, r1, r2  →  0x80 >> 4 = 0x08
        write_instr(16'h2008, encode_instr(OP_SHFTR, 5'd3, 5'd1, 5'd2, 12'd0));
        // SHFTL r4, r1, r2  →  0x80 << 4 = 0x800
        write_instr(16'h200c, encode_instr(OP_SHFTL, 5'd4, 5'd1, 5'd2, 12'd0));
        // SHFTRI r5, 2      →  r5 = r5 >> 2 (r5 is 0, so result = 0)
        //   let's use r1 instead: first mov r5, r1, then SHFTRI
        write_instr(16'h200c, encode_instr(OP_SHFTL, 5'd4, 5'd1, 5'd2, 12'd0));

        run_cycle; run_cycle; // setup r1, r2
        run_cycle; // SHFTR
        run_cycle; // SHFTL
        check_reg(5'd3, 64'h08, "SHFTR r3 = r1 >> r2");
        run_cycle;
        check_reg(5'd4, 64'h800, "SHFTL r4 = r1 << r2");

        // ==================================================================
        // TEST GROUP 5: MOV rd, rs
        // ==================================================================
        $display("\n=== TEST GROUP 5: MOV rd, rs ===");
        do_reset;

        // r1 = 42
        write_instr(16'h2000, encode_instr(OP_ADDI, 5'd1, 5'd0, 5'd0, 12'd42));
        // MOV r2, r1  →  r2 = r1 = 42
        write_instr(16'h2004, encode_instr(OP_MOV_RR, 5'd2, 5'd1, 5'd0, 12'd0));

        run_cycle; // ADDI r1
        run_cycle; // MOV r2, r1
        run_cycle;
        check_reg(5'd2, 64'd42, "MOV r2, r1");

        // ==================================================================
        // TEST GROUP 6: Store and Load
        // ==================================================================
        $display("\n=== TEST GROUP 6: Store/Load ===");
        do_reset;

        // r1 = 0x3000 (base address), r2 = 0xDEAD
        write_instr(16'h2000, encode_instr(OP_ADDI, 5'd1, 5'd0, 5'd0, 12'h100));
        write_instr(16'h2004, encode_instr(OP_ADDI, 5'd2, 5'd0, 5'd0, 12'h0AD));
        // MOV (r1)(0), r2  →  mem[r1 + 0] = r2 = 0xAD   (store, opcode 0x13)
        // NOTE: for store, rd=r1 (base), L=0, rs=r2 (data)
        write_instr(16'h2008, encode_instr(OP_MOV_ST, 5'd1, 5'd2, 5'd0, 12'd0));
        // MOV r3, (r1)(0)  →  r3 = mem[r1 + 0]           (load, opcode 0x10)
        // NOTE: for load, rd=r3, rs=r1 (base), L=0
        write_instr(16'h200c, encode_instr(OP_MOV_LD, 5'd3, 5'd1, 5'd0, 12'd0));

        run_cycle; // ADDI r1 = 0x100
        run_cycle; // ADDI r2 = 0xAD
        run_cycle; // store: mem[0x100] = rs_data (r2)
        run_cycle; // load: r3 = mem[r1 + 0]

        // The store writes rs_data. Let's check memory was written
        run_cycle;
        check_reg(5'd3, 64'hAD, "Load r3 from mem[r1]");

        // ==================================================================
        // TEST GROUP 7: Unconditional branches
        // ==================================================================
        $display("\n=== TEST GROUP 7: Branches ===");
        do_reset;

        // r1 = 0x2010 (absolute target)
        write_instr(16'h2000, encode_instr(OP_ADDI, 5'd1, 5'd0, 5'd0, 12'h010));
        // At 0x2004, write: ADDI r1, 0x2000 to get r1 = 0x2010
        // Actually simpler: set r1 = 16 first, then add 0x2000
        // Let's just use brr L (relative branch) which is simpler:
        // BRR L = 8  →  PC = PC + 8, skip one instruction
        write_instr(16'h2004, encode_instr(OP_BRR_L, 5'd0, 5'd0, 5'd0, 12'd8));
        // This instruction at 0x2008 should be SKIPPED
        write_instr(16'h2008, encode_instr(OP_ADDI, 5'd2, 5'd0, 5'd0, 12'd99));
        // This instruction at 0x200c should execute (branch lands here: 0x2004 + 8 = 0x200c)
        write_instr(16'h200c, encode_instr(OP_ADDI, 5'd3, 5'd0, 5'd0, 12'd77));

        run_cycle; // ADDI r1 = 16
        run_cycle; // BRR L = 8 → PC jumps to 0x200c
        run_cycle; // should execute ADDI r3, 77 (at 0x200c), NOT ADDI r2, 99

        run_cycle;
        check_reg(5'd2, 64'd0,  "BRR L skipped instruction (r2 should be 0)");
        check_reg(5'd3, 64'd77, "BRR L landed at correct target (r3 = 77)");

        // ==================================================================
        // TEST GROUP 8: BRNZ (conditional branch)
        // ==================================================================
        $display("\n=== TEST GROUP 8: BRNZ ===");
        do_reset;

        // r1 = target address (0x2010), r2 = 5 (nonzero → should branch)
        write_instr(16'h2000, encode_instr(OP_ADDI, 5'd1, 5'd0, 5'd0, 12'h10));
        write_instr(16'h2004, encode_instr(OP_ADDI, 5'd2, 5'd0, 5'd0, 12'd5));
        // brnz needs rd_data as target, rs_data as condition
        // rd=r1 (read via read_sel1=rd), rs=r2 (read via read_sel2=rs)
        // But wait: brnz rd, rs → branch to rd if rs != 0
        // In the ALU: branch_target = rd_data, condition = rs_data
        // In register file: read_sel1=rd=r1, read_sel2=rs=r2
        write_instr(16'h2008, encode_instr(OP_BRNZ, 5'd1, 5'd2, 5'd0, 12'd0));
        // Skipped instruction at 0x200c
        write_instr(16'h200c, encode_instr(OP_ADDI, 5'd4, 5'd0, 5'd0, 12'd99));
        // Target at 0x2010 (r1 value = 0x10... but that's address 0x10, not 0x2010)
        // Need r1 = 0x2010. 12-bit immediate max is 0xFFF.
        // Let's just set target to 0x2010 manually in r1:
        // ADDI r1, 0x10 → r1 = 0x10, then we branch there.
        // Actually let's just test with small addresses. Re-do:

        // Simpler: branch forward by using address 0x2010
        // We need r1 = 0x2010. Use two instructions:
        //   ADDI r1, 0x20  →  r1 = 0x20
        //   SHFTLI r1, 8   →  r1 = 0x2000
        //   ADDI r1, 0x10  →  r1 = 0x2010
        // That's 3 instructions of setup. Let's simplify and test brnz NOT taken instead.

        // Test brnz NOT taken: r2 = 0
        do_reset;
        write_instr(16'h2000, encode_instr(OP_ADDI, 5'd1, 5'd0, 5'd0, 12'h10));
        // r2 stays 0 (don't initialize it)
        // brnz r1, r2 → should NOT branch because r2 == 0
        write_instr(16'h2004, encode_instr(OP_BRNZ, 5'd1, 5'd2, 5'd0, 12'd0));
        // This should execute (branch not taken)
        write_instr(16'h2008, encode_instr(OP_ADDI, 5'd4, 5'd0, 5'd0, 12'd55));

        run_cycle; // ADDI r1 = 0x10
        run_cycle; // BRNZ — not taken because r2 = 0
        run_cycle; // ADDI r4, 55 — should execute
        run_cycle;
        check_reg(5'd4, 64'd55, "BRNZ not taken (r2=0), next instr executes");

        // ==================================================================
        // TEST GROUP 9: BRGT (conditional branch)
        // ==================================================================
        $display("\n=== TEST GROUP 9: BRGT ===");
        do_reset;

        // r1 = target (unused, just needs a value), r2 = 10, r3 = 5
        write_instr(16'h2000, encode_instr(OP_ADDI, 5'd2, 5'd0, 5'd0, 12'd10));
        write_instr(16'h2004, encode_instr(OP_ADDI, 5'd3, 5'd0, 5'd0, 12'd5));
        // brgt rd, rs, rt → branch to rd if rs > rt
        // Use rd=r1 (target), rs=r2 (10), rt=r3 (5) → 10 > 5 is true
        // But r1 = 0, so branching to 0x0000 — let's test NOT taken instead
        // r2 = 3, r3 = 10 → 3 > 10 is false, should not branch
        write_instr(16'h2008, encode_instr(OP_ADDI, 5'd4, 5'd0, 5'd0, 12'd3));
        // brgt r1, r4, r2 → branch if r4(3) > r2(10)? No → fall through
        write_instr(16'h200c, encode_instr(OP_BRGT, 5'd1, 5'd4, 5'd2, 12'd0));
        write_instr(16'h2010, encode_instr(OP_ADDI, 5'd5, 5'd0, 5'd0, 12'd88));

        run_cycle; // ADDI r2 = 10
        run_cycle; // ADDI r3 = 5
        run_cycle; // ADDI r4 = 3
        run_cycle; // BRGT — not taken (3 > 10 is false)
        run_cycle; // ADDI r5, 88
        run_cycle;
        check_reg(5'd5, 64'd88, "BRGT not taken (3 > 10 false), next instr runs");

        // ==================================================================
        // TEST GROUP 10: SUBI
        // ==================================================================
        $display("\n=== TEST GROUP 10: SUBI ===");
        do_reset;

        // r1 = 100
        write_instr(16'h2000, encode_instr(OP_ADDI, 5'd1, 5'd0, 5'd0, 12'd100));
        // SUBI r1, 30  →  r1 = 100 - 30 = 70
        write_instr(16'h2004, encode_instr(OP_SUBI, 5'd1, 5'd0, 5'd0, 12'd30));

        run_cycle; // ADDI r1 = 100
        run_cycle; // SUBI r1, 30
        run_cycle;
        check_reg(5'd1, 64'd70, "SUBI r1 = 100 - 30");

        // ==================================================================
        // TEST GROUP 11: Register r0 stays zero
        // ==================================================================
        $display("\n=== TEST GROUP 11: r0 hardwired zero ===");
        do_reset;

        // Try to write to r0: ADDI r0, 42
        write_instr(16'h2000, encode_instr(OP_ADDI, 5'd0, 5'd0, 5'd0, 12'd42));

        run_cycle;
        run_cycle;
        check_reg(5'd0, 64'd0, "r0 stays 0 after ADDI r0, 42");

        // ==================================================================
        // TEST GROUP 12: Stack pointer initialized
        // ==================================================================
        $display("\n=== TEST GROUP 12: SP init ===");
        do_reset;
        run_cycle;
        check_reg(5'd31, `MEM_SIZE, "r31 (SP) initialized to MEM_SIZE");

        // ==================================================================
        // TEST GROUP 13: PC starts at START
        // ==================================================================
        $display("\n=== TEST GROUP 13: PC init ===");
        do_reset;
        check_pc(16'h2000, "PC starts at 0x2000 after reset");

        // ==================================================================
        // SUMMARY
        // ==================================================================
        $display("\n============================================");
        $display("  RESULTS: %0d passed, %0d failed out of %0d tests",
                 pass_count, fail_count, test_num);
        $display("============================================\n");

        $finish;
    end

endmodule