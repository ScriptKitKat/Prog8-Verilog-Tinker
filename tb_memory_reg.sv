`timescale 1ns/1ps

`include "memory_reg.sv"

module tb_memory_reg;
    reg clk, reset;
    integer pass_count, fail_count;

    // ========== Memory signals ==========
    reg [63:0] mem_PC;
    wire [31:0] mem_instruction;
    reg [63:0] mem_data_address;
    wire [63:0] mem_data_out;
    wire mem_data_ready;
    reg mem_write_enable;
    reg [63:0] mem_write_address;
    reg [63:0] mem_write_data;

    memory uut_mem(
        .clk(clk),
        .reset(reset),
        .PC(mem_PC),
        .instruction(mem_instruction),
        .data_address(mem_data_address),
        .data_out(mem_data_out),
        .data_ready(mem_data_ready),
        .write_enable(mem_write_enable),
        .write_address(mem_write_address),
        .write_data(mem_write_data)
    );

    // ========== Register file signals ==========
    reg rf_write_enable;
    reg [63:0] rf_write_data;
    reg [4:0] rf_write_select;
    reg [4:0] rf_read_sel1, rf_read_sel2, rf_read_sel3;
    wire [63:0] rf_read_data1, rf_read_data2, rf_read_data3;
    wire [63:0] rf_read_r31;

    reg_file uut_rf(
        .clk(clk),
        .reset(reset),
        .write_enable(rf_write_enable),
        .write_data(rf_write_data),
        .write_select(rf_write_select),
        .read_sel1(rf_read_sel1),
        .read_sel2(rf_read_sel2),
        .read_sel3(rf_read_sel3),
        .read_data1(rf_read_data1),
        .read_data2(rf_read_data2),
        .read_data3(rf_read_data3),
        .read_r31(rf_read_r31)
    );

    // Clock generation
    always #5 clk = ~clk;

    task check64(input [63:0] got, input [63:0] expected, input [255:0] name);
        begin
            if (got === expected) begin
                $display("  PASS %0s: 0x%h", name, got);
                pass_count = pass_count + 1;
            end else begin
                $display("  FAIL %0s: got 0x%h, expected 0x%h", name, got, expected);
                fail_count = fail_count + 1;
            end
        end
    endtask

    task check32(input [31:0] got, input [31:0] expected, input [255:0] name);
        begin
            if (got === expected) begin
                $display("  PASS %0s: 0x%h", name, got);
                pass_count = pass_count + 1;
            end else begin
                $display("  FAIL %0s: got 0x%h, expected 0x%h", name, got, expected);
                fail_count = fail_count + 1;
            end
        end
    endtask

    initial begin
        clk = 0;
        reset = 1;
        pass_count = 0;
        fail_count = 0;
        mem_write_enable = 0;
        rf_write_enable = 0;
        mem_PC = 64'h2000;
        mem_data_address = 0;
        mem_write_address = 0;
        mem_write_data = 0;
        rf_write_data = 0;
        rf_write_select = 0;
        rf_read_sel1 = 0;
        rf_read_sel2 = 0;
        rf_read_sel3 = 0;

        // Reset
        @(posedge clk); #1;
        reset = 0;

        // ===================== MEMORY TESTS =====================
        $display("\n=== MEMORY: Write and Read ===");

        // Write 64-bit value to address 0x100
        mem_write_enable = 1;
        mem_write_address = 64'h100;
        mem_write_data = 64'hDEADBEEFCAFEBABE;
        @(posedge clk); #1;
        mem_write_enable = 0;

        // Read it back
        mem_data_address = 64'h100;
        #1;
        check64(mem_data_out, 64'hDEADBEEFCAFEBABE, "Read back written value");

        // Write a second value
        mem_write_enable = 1;
        mem_write_address = 64'h200;
        mem_write_data = 64'h0123456789ABCDEF;
        @(posedge clk); #1;
        mem_write_enable = 0;

        mem_data_address = 64'h200;
        #1;
        check64(mem_data_out, 64'h0123456789ABCDEF, "Read second value");

        // First value should still be there
        mem_data_address = 64'h100;
        #1;
        check64(mem_data_out, 64'hDEADBEEFCAFEBABE, "First value persists");

        $display("\n=== MEMORY: Instruction Fetch (little-endian) ===");

        // Write instruction bytes at PC=0x2000
        // Instruction: 0xAABBCCDD stored little-endian
        mem_write_enable = 1;
        mem_write_address = 64'h2000;
        mem_write_data = 64'h00000000AABBCCDD; // lower 32 bits
        @(posedge clk); #1;
        mem_write_enable = 0;

        mem_PC = 64'h2000;
        #1;
        // instruction = {bytes[PC+3], bytes[PC+2], bytes[PC+1], bytes[PC]}
        // bytes[2000]=DD, [2001]=CC, [2002]=BB, [2003]=AA
        check32(mem_instruction, 32'hAABBCCDD, "Instruction fetch little-endian");

        $display("\n=== MEMORY: data_ready always 1 ===");
        check64({63'b0, mem_data_ready}, 64'd1, "data_ready is always 1");

        // ===================== REGISTER FILE TESTS =====================
        $display("\n=== REG FILE: Reset State ===");

        // After reset, r0 should be 0
        reset = 1;
        @(posedge clk); #1;
        reset = 0;

        rf_read_sel1 = 5'd0;
        #1;
        check64(rf_read_data1, 64'h0, "r0 = 0 after reset");

        // r31 should be MEM_SIZE
        check64(rf_read_r31, 64'h80000, "r31 = MEM_SIZE (0x80000) after reset");

        rf_read_sel1 = 5'd15;
        #1;
        check64(rf_read_data1, 64'h0, "r15 = 0 after reset");

        $display("\n=== REG FILE: Write and Read ===");

        // Write to r1
        rf_write_enable = 1;
        rf_write_select = 5'd1;
        rf_write_data = 64'h42;
        @(posedge clk); #1;
        rf_write_enable = 0;

        rf_read_sel1 = 5'd1;
        #1;
        check64(rf_read_data1, 64'h42, "r1 = 0x42 after write");

        // Write to r10
        rf_write_enable = 1;
        rf_write_select = 5'd10;
        rf_write_data = 64'hFFFF;
        @(posedge clk); #1;
        rf_write_enable = 0;

        rf_read_sel2 = 5'd10;
        #1;
        check64(rf_read_data2, 64'hFFFF, "r10 = 0xFFFF via read_sel2");

        // Read 3 registers simultaneously
        rf_read_sel1 = 5'd1;
        rf_read_sel2 = 5'd10;
        rf_read_sel3 = 5'd0;
        #1;
        check64(rf_read_data1, 64'h42, "Simultaneous read: r1");
        check64(rf_read_data2, 64'hFFFF, "Simultaneous read: r10");
        check64(rf_read_data3, 64'h0, "Simultaneous read: r0");

        $display("\n=== REG FILE: r0 Hardwired Zero ===");

        // Attempt to write to r0
        rf_write_enable = 1;
        rf_write_select = 5'd0;
        rf_write_data = 64'h999;
        @(posedge clk); #1;
        rf_write_enable = 0;

        rf_read_sel1 = 5'd0;
        #1;
        check64(rf_read_data1, 64'h0, "r0 stays 0 after write attempt");

        $display("\n=== REG FILE: Write to r31 ===");

        rf_write_enable = 1;
        rf_write_select = 5'd31;
        rf_write_data = 64'h7FFF8;
        @(posedge clk); #1;
        rf_write_enable = 0;
        #1;
        check64(rf_read_r31, 64'h7FFF8, "r31 updated via write");

        $display("\n=== REG FILE: Write disabled ===");

        // write_enable = 0, write should not happen
        rf_write_enable = 0;
        rf_write_select = 5'd1;
        rf_write_data = 64'hBAD;
        @(posedge clk); #1;

        rf_read_sel1 = 5'd1;
        #1;
        check64(rf_read_data1, 64'h42, "r1 unchanged when write_enable=0");

        // ===================== SUMMARY =====================
        $display("\n============================================");
        $display("  MEMORY/REG RESULTS: %0d passed, %0d failed out of %0d tests",
                 pass_count, fail_count, pass_count + fail_count);
        $display("============================================");
        $finish;
    end
endmodule
