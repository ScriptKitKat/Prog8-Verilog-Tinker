`define MEM_SIZE 1024*512
`define START 16'h2000

module memory_unit(
    input clock,
    input reset,
    // instruction fetch
    input [63:0] PC,
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

    assign instruction = {memory[PC + 3], memory[PC + 2], memory[PC + 1], memory[PC]};

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