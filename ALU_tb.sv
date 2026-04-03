module ALU_tb ();
    `include "tinker.sv"

    reg clk;
    reg [4:0] opcode;
    reg [63:0] rd;
    reg [63:0] rs;
    reg [63:0] rt;
    reg [11:0] lit;
    wire [63:0] out;
    wire writeback;

    ALU uut (
        .clk(clk),
        .opcode(opcode),
        .rd(rd),
        .rs(rs),
        .rt(rt),
        .lit(lit),
        .out(out),
        .writeback(writeback)
    );

    always #10 clk = ~clk;
    initial begin
        $dumpfile("sim/ALU_tb.vcd");
        $dumpvars(0, ALU_tb);
        clk = 0;

        opcode = ADDF;
        rs = 64'h41e1c4e199277ddb; // pos to neg
        rt = 64'hc23cd88092d22198;
        #20 $display("%s ADDF 0 (%x)", out == 64'hc23c4a598608e5a9 ? "S" : "F", out);
        rs = 64'h3ff2000000000000; // perfect repr
        rt = 64'h40e2cb9000000000;
        #20 $display("%s ADDF 1 (%x)", out == 64'h40e2cbb400000000 ? "S" : "F", out);
        rs = 64'h3fc1442c7fbacb43; // imperfect repr
        rt = 64'h40e2cb8333333333;
        #20 $display("%s ADDF 2 (%x)", out == 64'h40e2cb87843e5322 ? "S" : "F", out);
        rs = 64'h0000000000000000; // zero
        rt = 64'h40e79886d42c3c9f;
        #20 $display("%s ADDF 3 (%x)", out == 64'h40e79886d42c3c9f ? "S" : "F", out);
        rs = 64'h197d86a0a707; // subnormal to normal
        rt = 64'h40e2cb8333333333;
        #20 $display("%s ADDF 4 (%x)", out == 64'h40e2cb8333333333 ? "S" : "F", out);
        rs = 64'h197d86a0a707; // subnormal to zero
        rt = 64'h0000000000000000;
        #20 $display("%s ADDF 5 (%x)", out == 64'h197d86a0a707 ? "S" : "F", out);
        rs = 64'h197d86a0a707; // subnormal to subnormal
        rt = 64'h2f;
        #20 $display("%s ADDF 6 (%x)", out == 64'h197d86a0a736 ? "S" : "F", out);
        rs = 64'h7ff8000000000000; // NAN + number
        rt = 64'h7FE1C4E163E00000;
        #20 $display("%s ADDF 7 (%x)", out == 64'h7ff8000000000000 ? "S" : "F", out);
        rs = 64'h7ff8000000000000; // NAN + INF
        rt = 64'h7ff0000000000000;
        #20 $display("%s ADDF 8 (%x)", out == 64'h7ff8000000000000 ? "S" : "F", out);
        rs = 64'h7ff0000000000000; // INF + number
        rt = 64'h439555a7d252f5af;
        #20 $display("%s ADDF 9 (%x)", out == 64'h7ff0000000000000 ? "S" : "F", out);
        rs = 64'h7ff0000000000000; // INF + -INF
        rt = 64'hfff0000000000000;
        #20 $display("%s ADDF 10 (%x)", out == 64'hfff8000000000000 ? "S" : "F", out);
        rs = 64'h3fb999999999999a; // 0.1 + 0.1
        rt = 64'h3fb999999999999a;
        #20 $display("%s ADDF 11 (%x)", out == 64'h3fc999999999999a ? "S" : "F", out);
        rs = 64'h3fb999999999999a; // 0.1 + -0.1
        rt = 64'hbfb999999999999a;
        #20 $display("%s ADDF 12 (%x)", out == 64'h0000000000000000 ? "S" : "F", out);
        rs = 64'hbfb999999999999a; // -0.1 + 0.1
        rt = 64'h3fb999999999999a;
        #20 $display("%s ADDF 13 (%x)", out == 64'h0000000000000000 ? "S" : "F", out);
        rs = 64'h7fe06b636f278ebf;
        rt = 64'h7fe1ca460eb6e59f;
        #20 $display("%s ADDF 14 (%x)", out == 64'h7ff0000000000000 ? "S" : "F", out);
        rs = 64'hffe06b636f278ebf;
        rt = 64'hffe1ca460eb6e59f;
        #20 $display("%s ADDF 15 (%x)", out == 64'hfff0000000000000 ? "S" : "F", out);
        rs = 64'hc4c93ea752dd3ba2; // neg + neg
        rt = 64'hc2401cb651190fdc;
        #20 $display("%s ADDF 16 (%x)", out == 64'hc4c93ea752dd4bbf ? "S" : "F", out);
        rs = 64'hc010000000000000; // perfect pos to neg
        rt = 64'h4000000000000000;
        #20 $display("%s ADDF 17 (%x)", out == 64'hc000000000000000 ? "S" : "F", out);
        rs = 64'hcd5d5955436e9f6b; // imperfect pos to neg
        rt = 64'h4cab9c0b02103243;
        #20 $display("%s ADDF 18 (%x)", out == 64'hcd5d55e1c20e5d65 ? "S" : "F", out);
        rs = 64'h4010000000000000; // result in 1
        rt = 64'hc008000000000000;
        #20 $display("%s ADDF 19 (%x)", out == 64'h3ff0000000000000 ? "S" : "F", out);
        rs = 64'hc008000000000000; // result in 1
        rt = 64'h4010000000000000;
        #20 $display("%s ADDF 20 (%x)", out == 64'h3ff0000000000000 ? "S" : "F", out);

        opcode = SUBF;
        rs = 64'h41e1c4e199277ddb; // pos to neg
        rt = 64'hc23cd88092d22198;
        #20 $display("%s SUBF 0 (%x)", out == 64'h423d66a79f9b5d87 ? "S" : "F", out);
        rs = 64'h3ff2000000000000; // perfect repr
        rt = 64'h40e2cb9000000000;
        #20 $display("%s SUBF 1 (%x)", out == 64'hc0e2cb6c00000000 ? "S" : "F", out);
        rs = 64'h3fc1442c7fbacb43; // imperfect repr
        rt = 64'h40e2cb8333333333;
        #20 $display("%s SUBF 2 (%x)", out == 64'hc0e2cb7ee2281344 ? "S" : "F", out);
        rs = 64'h0000000000000000; // zero
        rt = 64'h40e79886d42c3c9f;
        #20 $display("%s SUBF 3 (%x)", out == 64'hc0e79886d42c3c9f ? "S" : "F", out);
        rs = 64'h197d86a0a707; // subnormal to normal
        rt = 64'h40e2cb8333333333;
        #20 $display("%s SUBF 4 (%x)", out == 64'hc0e2cb8333333333 ? "S" : "F", out);
        rs = 64'h197d86a0a707; // subnormal to zero
        rt = 64'h0000000000000000;
        #20 $display("%s SUBF 5 (%x)", out == 64'h197d86a0a707 ? "S" : "F", out);
        rs = 64'h197d86a0a707; // subnormal to subnormal
        rt = 64'h2f;
        #20 $display("%s SUBF 6 (%x)", out == 64'h197d86a0a6d8 ? "S" : "F", out);
        rs = 64'h7ff8000000000000; // NAN + number
        rt = 64'h7FE1C4E163E00000;
        #20 $display("%s SUBF 7 (%x)", out == 64'h7ff8000000000000 ? "S" : "F", out);
        rs = 64'h7ff8000000000000; // NAN + INF
        rt = 64'h7ff0000000000000;
        #20 $display("%s SUBF 8 (%x)", out == 64'h7ff8000000000000 ? "S" : "F", out);
        rs = 64'h7ff0000000000000; // INF + number
        rt = 64'h439555a7d252f5af;
        #20 $display("%s SUBF 9 (%x)", out == 64'h7ff0000000000000 ? "S" : "F", out);
        rs = 64'h7ff0000000000000; // INF + -INF
        rt = 64'hfff0000000000000;
        #20 $display("%s SUBF 10 (%x)", out == 64'h7ff0000000000000 ? "S" : "F", out);
        rs = 64'h3fb999999999999a; // 0.1 + 0.1
        rt = 64'h3fb999999999999a;
        #20 $display("%s SUBF 11 (%x)", out == 64'h0000000000000000 ? "S" : "F", out);
        rs = 64'h3fb999999999999a; // 0.1 + -0.1
        rt = 64'hbfb999999999999a;
        #20 $display("%s SUBF 12 (%x)", out == 64'h3fc999999999999a ? "S" : "F", out);
        rs = 64'hbfb999999999999a; // -0.1 + 0.1
        rt = 64'h3fb999999999999a;
        #20 $display("%s SUBF 13 (%x)", out == 64'hbfc999999999999a ? "S" : "F", out);
        rs = 64'h7fe06b636f278ebf;
        rt = 64'h7fe1ca460eb6e59f;
        #20 $display("%s SUBF 14 (%x)", out == 64'hffa5ee29f8f56e00 ? "S" : "F", out);
        rs = 64'hffe06b636f278ebf;
        rt = 64'hffe1ca460eb6e59f;
        #20 $display("%s SUBF 15 (%x)", out == 64'h7fa5ee29f8f56e00 ? "S" : "F", out);
        rs = 64'hc4c93ea752dd3ba2; // neg + neg
        rt = 64'hc2401cb651190fdc;
        #20 $display("%s SUBF 16 (%x)", out == 64'hc4c93ea752dd2b85 ? "S" : "F", out);
        rs = 64'hc010000000000000; // perfect pos to neg
        rt = 64'h4000000000000000;
        #20 $display("%s SUBF 17 (%x)", out == 64'hc018000000000000 ? "S" : "F", out);
        rs = 64'hcd5d5955436e9f6b; // imperfect pos to neg
        rt = 64'h4cab9c0b02103243;
        #20 $display("%s SUBF 18 (%x)", out == 64'hcd5d5cc8c4cee171 ? "S" : "F", out);
        rs = 64'h4010000000000000; // result in 1
        rt = 64'hc008000000000000;
        #20 $display("%s SUBF 19 (%x)", out == 64'h401c000000000000 ? "S" : "F", out);
        rs = 64'hc008000000000000; // result in 1
        rt = 64'h4010000000000000;
        #20 $display("%s SUBF 20 (%x)", out == 64'hc01c000000000000 ? "S" : "F", out);

        opcode = MULF;
        rs = 64'h3ff2000000000000; // perfect repr
        rt = 64'h40e2cb9000000000;
        #20 $display("%s MULF 1 (%x)", out == 64'h40e5250200000000 ? "S" : "F", out);
        rs = 64'h3fc1442c7fbacb43; // imperfect repr
        rt = 64'h40e2cb8333333333;
        #20 $display("%s MULF 2 (%x)", out == 64'h40b4485099b39acd ? "S" : "F", out);
        rs = 64'h0000000000000000; // zero
        rt = 64'h40e79886d42c3c9f;
        #20 $display("%s MULF 3 (%x)", out == 64'h0000000000000000 ? "S" : "F", out);
        rs = 64'h197d86a0a707; // subnormal to normal
        rt = 64'h55087bef5d1a572d;
        #20 $display("%s MULF 4 (%x)", out == 64'h14b380de21a611d4 ? "S" : "F", out);
        rs = 64'h197d86a0a707; // subnormal to zero
        rt = 64'h45;
        #20 $display("%s MULF 5 (%x)", out == 64'h0000000000000000 ? "S" : "F", out);
        rs = 64'h197d86a0a707; // subnormal to subnormal
        rt = 64'h3dc2d2231f509e79;
        #20 $display("%s MULF 6 (%x)", out == 64'h3bf ? "S" : "F", out);
        rs = 64'h7ff8000000000000; // NAN * number
        rt = 64'h439555a7d252f5af;
        #20 $display("%s MULF 7 (%x)", out == 64'h7ff8000000000000 ? "S" : "F", out);
        rs = 64'h7ff8000000000000; // NAN * INF
        rt = 64'h7ff0000000000000;
        #20 $display("%s MULF 8 (%x)", out == 64'h7ff8000000000000 ? "S" : "F", out);
        rs = 64'h7ff0000000000000; // INF * number
        rt = 64'h439555a7d252f5af;
        #20 $display("%s MULF 9 (%x)", out == 64'h7ff0000000000000 ? "S" : "F", out);
        rs = 64'h7ff0000000000000; // INF * -INF
        rt = 64'hfff0000000000000;
        #20 $display("%s MULF 10 (%x)", out == 64'hfff0000000000000 ? "S" : "F", out);
        rs = 64'h7fe06b636f278ebf;
        rt = 64'h7fe1ca460eb6e59f;
        #20 $display("%s MULF 11 (%x)", out == 64'h7ff0000000000000 ? "S" : "F", out);
        rs = 64'h7fe06b636f278ebf;
        rt = 64'hffe1ca460eb6e59f;
        #20 $display("%s MULF 12 (%x)", out == 64'hfff0000000000000 ? "S" : "F", out);
        rs = 64'h8000000000000af3; // underflow to zero
        rt = 64'h3e7ad7f29abcaf48;
        #20 $display("%s MULF 13 (%x)", out == 64'h8000000000000000 ? "S" : "F", out);
        rs = 64'haf3; // underflow to zero
        rt = 64'h3e7ad7f29abcaf48;
        #20 $display("%s MULF 14 (%x)", out == 64'h0000000000000000 ? "S" : "F", out);
        rs = 64'h48035b4fd2e204ec; // big times big
        rt = 64'h488e34b1ef575c40;
        #20 $display("%s MULF 15 (%x)", out == 64'h50a2457ad942ee95 ? "S" : "F", out);
        rs = 64'h197d86a0a707; // sub to sub
        rt = 64'h3ed20916fff6c5c5;
        #20 $display("%s MULF 16 (%x)", out == 64'h72eecad ? "S" : "F", out);

        opcode = DIVF;
        rs = 64'h4010000000000000; // perfect repr
        rt = 64'h4000000000000000;
        #20 $display("%s DIVF 1 (%x)", out == 64'h4000000000000000 ? "S" : "F", out);
        rs = 64'h413c1ef6225460aa; // imperfect repr
        rt = 64'h3ff36a23a271847d;
        #20 $display("%s DIVF 2 (%x)", out == 64'h41372cd22c4ae7a5 ? "S" : "F", out);
        rs = 64'h413c1ef6225460aa; // div by <1
        rt = 64'h3daf8d509723c86d;
        #20 $display("%s DIVF 3 (%x)", out == 64'h437c852ce811cc42 ? "S" : "F", out);
        rs = 64'h403f2119e3d6d48e; // div by subnormal (to inf)
        rt = 64'h197d86a0a707;
        #20 $display("%s DIVF 4 (%x)", out == 64'h7ff0000000000000 ? "S" : "F", out);
        rs = 64'h41ecadd4e243f712; // div by inf (to zero)
        rt = 64'h7ff0000000000000;
        #20 $display("%s DIVF 5 (%x)", out == 64'h0000000000000000 ? "S" : "F", out);
        rs = 64'h3d77bae7d14be2c6; // div to subnormal
        rt = 64'h7fdd50c020dc9fc7;
        #20 $display("%s DIVF 6 (%x)", out == 64'hcf4 ? "S" : "F", out);
        rs = 64'h7ff0000000000000; // inf / inf
        rt = 64'h7ff0000000000000;
        #20 $display("%s DIVF 7 (%x)", out == 64'hfff8000000000000 ? "S" : "F", out);
        rs = 64'h7ff0000000000000; // inf / -inf
        rt = 64'hfff0000000000000;
        #20 $display("%s DIVF 8 (%x)", out == 64'hfff8000000000000 ? "S" : "F", out);
        rs = 64'h0000000000000000; // 0 / num
        rt = 64'h42815a4422d9b110;
        #20 $display("%s DIVF 9 (%x)", out == 64'h0000000000000000 ? "S" : "F", out);
        rs = 64'h0000000000000000; // 0 / subnormal
        rt = 64'h197d86a0a707;
        #20 $display("%s DIVF 10 (%x)", out == 64'h0000000000000000 ? "S" : "F", out);
        rs = 64'h0000000000000000; // 0 / inf
        rt = 64'h7ff0000000000000;
        #20 $display("%s DIVF 11 (%x)", out == 64'h0000000000000000 ? "S" : "F", out);
        rs = 64'h0000000000000000; // 0 / -inf
        rt = 64'hfff0000000000000;
        #20 $display("%s DIVF 12 (%x)", out == 64'h8000000000000000 ? "S" : "F", out);
        rs = 64'h0000000000000000; // 0 / NAN
        rt = 64'h7ff8000000000000;
        #20 $display("%s DIVF 13 (%x)", out == 64'h7ff8000000000000 ? "S" : "F", out);
        rs = 64'h7ff8000000000000; // NAN / NAN
        rt = 64'h7ff8000000000000;
        #20 $display("%s DIVF 14 (%x)", out == 64'h7ff8000000000000 ? "S" : "F", out);
        rs = 64'h7ff0000000000000; // INF / NAN
        rt = 64'h7ff8000000000000;
        #20 $display("%s DIVF 15 (%x)", out == 64'h7ff8000000000000 ? "S" : "F", out);
        rs = 64'h41e2199d3943f0a0; // num / 0
        rt = 64'h0000000000000000;
        #20 $display("%s DIVF 16 (%x)", out == 64'h7ff8000000000000 ? "S" : "F", out);
        rs = 64'h7ff0000000000000; // inf / 0
        rt = 64'h0000000000000000;
        #20 $display("%s DIVF 17 (%x)", out == 64'h7ff0000000000000 ? "S" : "F", out);
        rs = 64'h3a96a56f947b2655; // div to zero
        rt = 64'h7f84d4b453882444;
        #20 $display("%s DIVF 18 (%x)", out == 64'h0000000000000000 ? "S" : "F", out);

        $finish();
    end

//    initial begin
//        $monitor("Time=%t | Opcode=%b | Rd=%x | Rs=%x | Rt = %x | Lit = %x | Out = %x | Writeback = %b",
//                 $time, opcode, rd, rs, rt, lit, out, writeback);
//    end
endmodule