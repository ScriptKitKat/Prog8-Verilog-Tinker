`include "alu.sv"
`include "memory_reg.sv"

module tinker_core(
    input clk,
    input reset
);
    `include "constants.vh"

    reg [63:0] PC;
    wire [63:0] next_PC;

    // Instruction fetch
    wire [31:0] instruction;

    // Decode
    wire [4:0] opcode;
    wire [4:0] rd_sel, rs_sel, rt_sel;
    wire [11:0] L;
    wire [63:0] extended_L;
    assign extended_L = {{52{L[11]}}, L};

    // Register data
    wire [63:0] rd_data, rs_data, rt_data, r31_data;

    // Memory
    wire [63:0] mem_read_data;
    wire mem_data_ready;

    // ALU
    wire [63:0] alu_out;
    wire alu_writeback;

    // Branch logic (handled in tinker_core since ALU is now standalone)
    reg [63:0] branch_target;
    reg branch_taken;

    // Control signals
    wire is_load, is_store, is_call, is_return, is_halt;
    wire is_branch;
    wire mem_write_en;
    wire reg_write_en;

    assign is_load   = (opcode == MOV_LD);
    assign is_store  = (opcode == MOV_ST);
    assign is_call   = (opcode == CALL);
    assign is_return = (opcode == RET);
    assign is_halt   = (opcode == 5'h1F);
    assign is_branch = (opcode == BR) || (opcode == BRR_R) || (opcode == BRR_L) ||
                       (opcode == BRNZ) || (opcode == CALL) || (opcode == RET) ||
                       (opcode == BRGT);

    // Memory write: store (0x13) and call (0x0c)
    assign mem_write_en = is_store || is_call;

    // Register write: ALU writeback signal, plus loads
    assign reg_write_en = (alu_writeback && !is_store) || is_load;

    // What data goes to memory write port
    wire [63:0] mem_write_data;
    assign mem_write_data = is_call  ? (PC + 64'd4) :   // CALL: save return address
                            is_store ? rs_data :          // store: rs value
                            64'b0;

    // Memory write address
    // For CALL: alu_out = r31 - 8 (but we need to compute this here since ALU just passes rd)
    // For store: alu_out = rd + L (address)
    wire [63:0] mem_write_addr;
    assign mem_write_addr = is_call ? (r31_data - 64'd8) : alu_out;

    // Memory read address (for loads and return)
    wire [63:0] mem_read_addr;
    assign mem_read_addr = is_return ? r31_data : alu_out;

    // Writeback data MUX
    wire [63:0] writeback_data;
    assign writeback_data = is_load       ? mem_read_data :
                            (opcode == MOV_UP) ? {L, rd_data[51:0]} :
                            alu_out;

    // Branch logic — computed here, not in ALU
    always @(*) begin
        branch_target = PC + 64'd4;
        branch_taken = 1'b0;

        case (opcode)
            BR: begin
                branch_target = rd_data;
                branch_taken = 1'b1;
            end
            BRR_R: begin
                branch_target = PC + rd_data;
                branch_taken = 1'b1;
            end
            BRR_L: begin
                branch_target = PC + extended_L;
                branch_taken = 1'b1;
            end
            BRNZ: begin
                branch_target = rd_data;
                if (rs_data != 64'b0)
                    branch_taken = 1'b1;
            end
            CALL: begin
                branch_target = rd_data;
                branch_taken = 1'b1;
            end
            RET: begin
                // branch_target comes from memory, handled in next_PC
                branch_taken = 1'b0; // handled specially
            end
            BRGT: begin
                branch_target = rd_data;
                if (rs_data > rt_data)
                    branch_taken = 1'b1;
            end
            default: begin
                branch_target = PC + 64'd4;
                branch_taken = 1'b0;
            end
        endcase
    end

    // Next PC
    assign next_PC = is_halt       ? PC :
                     is_return     ? mem_read_data :
                     branch_taken  ? branch_target :
                     (PC + 64'd4);

    // ---- Module instantiations (names matter for autograder!) ----

    memory_unit memory(
        .clk(clk),
        .reset(reset),
        .PC(PC),
        .instruction(instruction),
        .data_address(mem_read_addr),
        .data_out(mem_read_data),
        .data_ready(mem_data_ready),
        .write_enable(mem_write_en),
        .write_address(mem_write_addr),
        .write_data(mem_write_data)
    );

    instruction_decoder dec(
        .instruction(instruction),
        .opcode(opcode),
        .rd(rd_sel),
        .rs(rs_sel),
        .rt(rt_sel),
        .L(L)
    );

    register_file reg_file(
        .clk(clk),
        .reset(reset),
        .write_enable(reg_write_en),
        .write_data(writeback_data),
        .write_select(rd_sel),
        .read_sel1(rd_sel),
        .read_sel2(rs_sel),
        .read_sel3(rt_sel),
        .read_data1(rd_data),
        .read_data2(rs_data),
        .read_data3(rt_data),
        .read_r31(r31_data)
    );

    ALU alu(
        .clk(clk),
        .opcode(opcode),
        .rd(rd_data),
        .rs(rs_data),
        .rt(rt_data),
        .lit(L),
        .out(alu_out),
        .writeback(alu_writeback)
    );

    // PC register
    always @(posedge clk or posedge reset) begin
        if (reset)
            PC <= `START;
        else
            PC <= next_PC;
    end
endmodule

module instruction_decoder(
    input [31:0] instruction,
    output [4:0] opcode,
    output [4:0] rd,
    output [4:0] rs,
    output [4:0] rt,
    output [11:0] L
);
    assign opcode = instruction[4:0];
    assign rd     = instruction[9:5];
    assign rs     = instruction[14:10];
    assign rt     = instruction[19:15];
    assign L      = instruction[31:20];
endmodule