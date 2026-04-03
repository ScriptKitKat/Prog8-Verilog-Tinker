`include "alu.sv"
`include "memory_reg.sv"

module tinker_core(
    input clk,
    input reset
);
    // CONTROL SIGNAL FLOW
    reg [63:0] PC;
    wire [63:0] next_PC;

    // Instruction fetch wire
    wire [31:0] instruction;

    // Decode outputs wires
    wire [4:0] opcode;
    wire [4:0] rd, rs, rt;
    wire [11:0] L;

    // Register data outputs
    wire [63:0] rd_data, rs_data, rt_data, r31_data;

    // Memory
    wire [63:0] mem_read_data;
    wire mem_data_ready;

    // ALU
    wire [63:0] alu_result;
    wire alu_writeback;
    wire [63:0] alu_branch_target;
    wire alu_branch_taken;

    // Control Instruction type classification
    wire is_alu_reg; // add, sub, mul, div, and, or, xor, not, shftr, shftl, fadd, fsub, fmul, fpu_div_result
    wire is_alu_L; // addi, subi, shftri, shftri
    wire is_mov_rd; // mov rd, rs
    wire is_mov_L;
    wire is_branch_L; // brr L
    wire is_L;
    wire is_return;

    wire reg_write_en;
    wire mem_write_en;

    assign is_alu_reg = (opcode == 5'h18) || (opcode == 5'h1a) || (opcode == 5'h1c) || (opcode == 5'h1d) || 
    (opcode == 5'h00) || (opcode == 5'h01) || (opcode == 5'h02) || (opcode == 5'h03) || (opcode == 5'h04) ||
    (opcode == 5'h06) || (opcode == 5'h14) || (opcode == 5'h15) || (opcode == 5'h16) || (opcode == 5'h17);
    
    assign is_alu_L = (opcode == 5'h19) || (opcode == 5'h1b) || (opcode == 5'h05) || (opcode == 5'h07);

    // also need to check if we have to read rd --> brr rd, brr rd, brnz, call, brgt, 
    assign is_mov_rd = (opcode == 5'h10) || (opcode == 5'h11) || (opcode == 5'h12);
    assign is_mov_L = (opcode == 5'h10) || (opcode == 5'h12) || (opcode == 5'h13);
    assign is_branch_L = (opcode == 5'h0a);

    assign is_L = is_alu_L || is_branch_L || is_mov_L;

    wire is_call, is_branch_reg;
    assign is_call = (opcode == 5'h0c);
    assign is_branch_reg = (opcode == 5'h08) || (opcode == 5'h09);

    assign reg_write_en = is_alu_reg || is_alu_L || is_mov_rd || is_call || is_return;
    assign mem_write_en = (opcode == 5'h13) || (opcode == 5'h0c);

    assign is_return = (opcode == 5'h0d);

    // For RETURN, memory read address is r31 (not alu_result)
    wire [63:0] mem_data_addr;
    assign mem_data_addr = is_return ? r31_data : alu_result;

    wire [63:0] mem_write_data;
    assign mem_write_data = (opcode == 5'h0c) ? (PC + 64'd4) :
                        (opcode == 5'h13) ? rs_data :
                        rt_data;

    memory memory(
        .clk(clk),
        .reset(reset),
        .PC(PC),
        .instruction(instruction),
        .data_address(mem_data_addr),
        .data_out(mem_read_data),
        .data_ready(mem_data_ready),
        .write_enable(mem_write_en),
        .write_address(alu_result),
        .write_data(mem_write_data)
    );
    
    instruction_decoder dec(
        .instruction(instruction),
        .opcode(opcode),
        .rd(rd),
        .rs(rs),
        .rt(rt),
        .L(L)
    );

    assign next_PC = is_return ? mem_read_data :
                    alu_branch_taken ? alu_branch_target :
                    (PC + 64'd4);
    
    wire [63:0] writeback_data;
    assign writeback_data = (opcode == 5'h10) ? mem_read_data :
                        (opcode == 5'h12) ? {rd_data[63:12], L} :
                        alu_result;

    // CALL/RETURN write to r31, all others write to rd
    wire [4:0] write_reg;
    assign write_reg = (is_call || is_return) ? 5'd31 : rd;

    reg_file reg_file(
        .clk(clk),
        .reset(reset),
        .write_enable(reg_write_en),
        .write_data(writeback_data),
        .write_select(write_reg),
        .read_sel1(rd),
        .read_sel2(rs),
        .read_sel3(rt),
        .read_data1(rd_data),
        .read_data2(rs_data),
        .read_data3(rt_data),
        .read_r31(r31_data)
    );

    
    ALU alu(
        .opcode(opcode),
        .PC(PC),
        .rd_data(rd_data),
        .rs_data(rs_data),
        .rt_data(rt_data),
        .r31_data(r31_data),
        .L_data(L),
        .result(alu_result),
        .writeback(alu_writeback),
        .branch_target(alu_branch_target),
        .branch_taken(alu_branch_taken)
    );
    
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            PC <= `START;
        end else begin
            PC <= next_PC;
        end
    end
endmodule

module instruction_decoder(
    input [31:0] instruction,
    output reg [4:0] opcode,
    output reg [4:0] rd,
    output reg [4:0] rs,
    output reg [4:0] rt,
    output reg [11:0] L
);
    always @(*) begin
        opcode = instruction[31:27];
        rd = instruction[26:22];
        rs = instruction[21:17];
        rt = instruction[16:12];
        L = instruction[11:0];
    end
endmodule