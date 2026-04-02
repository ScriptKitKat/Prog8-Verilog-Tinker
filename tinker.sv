`define MEM_SIZE 1024*512
`define START 16'h2000

module tinker_core(
    input clk,
    input reset
);
    // Fetch -> decode -> read registers -> execute -> writeback -> PC update
    // PC
    reg [63:0] PC;
    wire [63:0] next_PC;

    wire [31:0] instruction;

    // Decode outputs
    wire [4:0] opcode;
    wire [4:0] rd, rs, rt;
    wire [11:0] L;

    // Register data outputs
    wire [63:0] reg_data1;
    wire [63:0] reg_data2;

    wire [63:0] alu_operand1;
    wire [63:0] alu_operand2;
    wire [63:0] alu_result;

    // Memory
    wire [63:0] mem_read_data;
    wire mem_data_ready;

    wire is_load;
    wire is_store;
    wire is_branch;
    wire is_jump;
    wire is_alu_op;
    wire reg_write_en;
    wire mem_write_en;

    memory_unit memory(
        .clk(clk),
        .reset(reset),
        .instr_address(PC),
        .instruction(instruction),
        .data_address(alu_result), // rd + L
        .data_out(mem_read_data),
        .data_ready(mem_data_ready),
        .write_enable(mem_write_en),
        .write_address(alu_result),
        .write_data(reg_data2) // ???
    );

    instruction_decoder dec(
        .instruction(instruction),
        .opcode(opcode),
        .rd(rd),
        .rs(rs),
        .rt(rt),
        .L(L)
    );

    wire [63:0] writeback_data;
    assign writeback_data = is_load ? mem_read_data : alu_result;

    register_file regfile(
        .clk(clk),
        .reset(reset),
        .write_enable(reg_write_en),
        .write_data(writeback_data),
        .write_select(rd),
        .read_sel1(rs),
        .read_sel2(rt),
        .read_data1(reg_data1),
        .read_data2(reg_data2)
    );

    wire [63:0] extended_L;
    assign extended_L = {{52{L[11]}}, L}; // Sign-extend
    assign alu_operand2 = is_immediate ? extended_L : reg_data2;

    ALU alu(
        .opcode(opcode),
        .operand1(reg_data1),
        .operand2(alu_operand2),
        .result(alu_result)
    );

    assign next_PC = PC + 64'd4; // Default to next instruction


    always @(posedge clk or posedge reset) begin
        if (reset) begin
            PC <= `START;
        end else begin
            PC <= next_PC;
        end
    end
endmodule

module instruction_fetch(
    input clk,
    input reset,
    input enable,
    input [63:0] PC,
    input memory memory,
    output reg [31:0] line
);
    always @(posedge clk) begin
        line <= {memory[PC+3], memory[PC+2], memory[PC+1], memory[PC]};
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
        opcode = instruction[4:0];
        rd = instruction[9:5];
        rs = instruction[14:10];
        rt = instruction[19:15];
        L = instruction[31:20];
    end
endmodule

module register(
    input clk,
    input reset,
    input write_enable,
    input [63:0] write_data,
    input [4:0] write_select,
    input [4:0] read_sel1,
    input [4:0] read_sel2,
    output [63:0] read_data1,
    output [63:0] read_data2
);
    reg [63:0] registers [31:0];

    // Reads are combinational
    assign read_data1 = registers[read_sel1];
    assign read_data2 = registers[read_sel2];

    integer i;
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            for (i = 0; i < 31; i = i + 1) begin
                registers[i] <= 64'b0;
            end
            registers[31] <= `MEM_SIZE; // Stack Pointer initialized to the end of memory
        end else if (write_enable && write_select != 5'b0) begin
            registers[write_select] <= write_data;
        end
    end
endmodule


module memory_unit(
    input clock,
    input reset,
    // instruction fetch
    input [63:0] instr_address,
    output instruction,
    // data load
    input [63:0] data_address,
    output [63:0] data_out,
    output data_ready,
    // data write
    input write_enable,
    input [63:0] write_address,
    input [63:0] write_data
);
    reg [7:0] memory [0:`MEM_SIZE - 1]

    assign instruction = {memory[instr_address + 3], memory[instr_address + 2], memory[instr_address + 1], memory[instr_address]};

    assign data_out = {memory[data_address + 7], memory[data_address + 6], memory[data_address + 5], memory[data_address + 4],
                       memory[data_address + 3], memory[data_address + 2], memory[data_address + 1], memory[data_address]};

    assign data_ready = 1'b1;

    always @(posedge clk or posedge reset) begin
        if (write_enable) begin
            memory[write_address] <= write_data[7:0];
            memory[write_address + 1] <= write_data[15:8];
            memory[write_address + 2] <= write_data[23:16];
            memory[write_address + 3] <= write_data[31:24];
            memory[write_address + 4] <= write_data[39:32];
            memory[write_address + 5] <= write_data[47:40];
            memory[write_address + 6] <= write_data[55:48];
            memory[write_address + 7] <= write_data[63:56];
        end
    end
endmodule

module ALU(
    input [4:0] opcode,
    input [63:0] operand1,
    input [63:0] operand2,
    output reg [63:0] result
);
    wire [63:0] fpu_add_result;
    wire [63:0] fpu_sub_result;
    wire [63:0] fpu_mul_result;
    wire [63:0] fpu_div_result;

    fpu_add fpu_add_unit(
        .a(operand1),
        .b(operand2),
        .result(fpu_add_result)
    );

    fpu_mul fpu_mul_unit(
        .a(operand1),
        .b(operand2),
        .result(fpu_mul_result)
    );

    fpu_div fpu_div_unit(
        .a(operand1),
        .b(operand2),
        .result(fpu_div_result)
    );

    wire [63:0] negated;
    assign negated = {~operand2[63], operand[62:0]};
    fpu_add fpu_sub_unit(
        .a(operand1),
        .b(negated),
        .result(fpu_sub_result)
    );

    always @(*) begin
        case (opcode)
            5'h18: result = operand1 + operand2; // ADD
            5'h19: result = operand1 + operand2; // ADDI
            5'h1a: result = operand1 - operand2; // SUB
            5'h1b: result = operand1 - operand2; // SUBI
            5'h1c: result = operand1 * operand2; // MUL
            5'h1d: result = operand1 / operand2; // DIV
            5'h0: result = operand1 & operand2; // AND
            5'h1: result = operand1 | operand2; // OR
            5'h2: result = operand1 ^ operand2; // XOR
            5'h3: result = ~operand1; // NOT
            5'h4: result = operand1 >> operand2; // SHFTR
            5'h5: result = operand1 >> operand2; // SHFTRI
            5'h6: result = operand1 << operand2; // SHFTL
            5'h7: result = operand1 << operand2; // SHFTLI
            // FPU operations in another file: fpu.sv
            5'h14: result = fpu_add_result; // FADD
            5'h15: result = fpu_sub_result; // FSUB
            5'h16: result = fpu_mul_result; // FMUL
            5'h17: result = fpu_div_result; // FDIV
        endcase
    end
endmodule