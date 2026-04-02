// How many infinities? 2
module fp_class_tb;
    reg [63:0] a;
    wire [7:0] nan, infinity, zero, subnormal, normal;

    

    fpu_class fpu_class(.f(a), .nan(nan), .infinity(infinity), .zero(zero), .subnormal(subnormal), .normal(normal));
endmodule