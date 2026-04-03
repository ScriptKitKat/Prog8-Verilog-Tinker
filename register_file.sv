
module register(
    input clk,
    input reset,
    input write_enable,
    input [63:0] write_data,
    input [4:0] write_select,
    input [4:0] read_sel1,
    input [4:0] read_sel2,
    input [4:0] read_sel3,
    output [63:0] read_data1,
    output [63:0] read_data2,
    output [63:0] read_data3
);
    reg [63:0] registers [31:0];

    // Reads are combinational
    assign read_data1 = registers[read_sel1];
    assign read_data2 = registers[read_sel2];
    assign read_data3 = registers[read_sel3];

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
