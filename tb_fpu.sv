`timescale 1ns/1ps

`include "fpu.sv"

module tb_fpu;
    reg [63:0] a, b;
    wire [63:0] add_result, sub_result, mul_result, div_result;

    integer pass_count, fail_count;

    fpu_add uut_add(.a(a), .b(b), .result(add_result));

    wire [63:0] neg_b = {~b[63], b[62:0]};
    fpu_add uut_sub(.a(a), .b(neg_b), .result(sub_result));

    fpu_mul uut_mul(.a(a), .b(b), .result(mul_result));
    fpu_div uut_div(.a(a), .b(b), .result(div_result));

    task check(input [63:0] got, input [63:0] expected, input [255:0] name);
        begin
            if (got === expected) begin
                $display("  PASS %0s: got %h", name, got);
                pass_count = pass_count + 1;
            end else begin
                $display("  FAIL %0s: got %h, expected %h", name, got, expected);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // IEEE 754 double constants
    localparam [63:0] POS_ZERO  = 64'h0000000000000000;
    localparam [63:0] NEG_ZERO  = 64'h8000000000000000;
    localparam [63:0] POS_INF   = 64'h7FF0000000000000;
    localparam [63:0] NEG_INF   = 64'hFFF0000000000000;
    localparam [63:0] QNAN_PROP = 64'h7FF8000000000000; // propagated NaN
    localparam [63:0] QNAN_GEN  = 64'hFFF8000000000000; // generated NaN
    localparam [63:0] SNAN      = 64'h7FF0000000000001; // signaling NaN

    // Common values
    localparam [63:0] ONE       = 64'h3FF0000000000000; // 1.0
    localparam [63:0] TWO       = 64'h4000000000000000; // 2.0
    localparam [63:0] THREE     = 64'h4008000000000000; // 3.0
    localparam [63:0] FOUR      = 64'h4010000000000000; // 4.0
    localparam [63:0] FIVE      = 64'h4014000000000000; // 5.0
    localparam [63:0] TEN       = 64'h4024000000000000; // 10.0
    localparam [63:0] HALF      = 64'h3FE0000000000000; // 0.5
    localparam [63:0] NEG_ONE   = 64'hBFF0000000000000; // -1.0
    localparam [63:0] NEG_TWO   = 64'hC000000000000000; // -2.0
    localparam [63:0] SIX       = 64'h4018000000000000; // 6.0
    localparam [63:0] PI        = 64'h400921FB54442D18; // 3.14159265358979...
    localparam [63:0] E_VAL     = 64'h4005BF0A8B145769; // 2.71828182845904...

    initial begin
        pass_count = 0;
        fail_count = 0;

        // ===================== FPU ADD =====================
        $display("\n=== FPU ADD ===");

        // Basic addition
        a = ONE; b = ONE; #10;
        check(add_result, TWO, "1.0 + 1.0 = 2.0");

        a = ONE; b = TWO; #10;
        check(add_result, THREE, "1.0 + 2.0 = 3.0");

        a = TWO; b = THREE; #10;
        check(add_result, FIVE, "2.0 + 3.0 = 5.0");

        // Add with zero
        a = FIVE; b = POS_ZERO; #10;
        check(add_result, FIVE, "5.0 + 0.0 = 5.0");

        a = POS_ZERO; b = TEN; #10;
        check(add_result, TEN, "0.0 + 10.0 = 10.0");

        // Negative addition
        a = NEG_ONE; b = NEG_ONE; #10;
        check(add_result, NEG_TWO, "-1.0 + -1.0 = -2.0");

        // Cancellation (subtraction via add)
        a = ONE; b = NEG_ONE; #10;
        check(add_result, POS_ZERO, "1.0 + (-1.0) = 0.0");

        // Infinity
        a = POS_INF; b = ONE; #10;
        check(add_result, POS_INF, "inf + 1.0 = inf");

        a = POS_INF; b = POS_INF; #10;
        check(add_result, POS_INF, "inf + inf = inf");

        a = POS_INF; b = NEG_INF; #10;
        check(add_result, QNAN_GEN, "inf + (-inf) = NaN (generated)");

        // NaN propagation
        a = SNAN; b = ONE; #10;
        check(add_result, QNAN_PROP, "NaN + 1.0 = NaN (propagated)");

        a = ONE; b = SNAN; #10;
        check(add_result, QNAN_PROP, "1.0 + NaN = NaN (propagated)");

        // ===================== FPU SUB =====================
        $display("\n=== FPU SUB (via negation) ===");

        a = FIVE; b = THREE; #10;
        check(sub_result, TWO, "5.0 - 3.0 = 2.0");

        a = ONE; b = ONE; #10;
        check(sub_result, POS_ZERO, "1.0 - 1.0 = 0.0");

        a = THREE; b = FIVE; #10;
        check(sub_result, NEG_TWO, "3.0 - 5.0 = -2.0");

        a = POS_ZERO; b = ONE; #10;
        check(sub_result, NEG_ONE, "0.0 - 1.0 = -1.0");

        // ===================== FPU MUL =====================
        $display("\n=== FPU MUL ===");

        a = TWO; b = THREE; #10;
        check(mul_result, 64'h4018000000000000, "2.0 * 3.0 = 6.0");

        a = FOUR; b = HALF; #10;
        check(mul_result, TWO, "4.0 * 0.5 = 2.0");

        a = NEG_ONE; b = FIVE; #10;
        check(mul_result, 64'hC014000000000000, "-1.0 * 5.0 = -5.0");

        a = NEG_ONE; b = NEG_ONE; #10;
        check(mul_result, ONE, "-1.0 * -1.0 = 1.0");

        // Multiply by zero
        a = TEN; b = POS_ZERO; #10;
        check(mul_result, POS_ZERO, "10.0 * 0.0 = 0.0");

        // Multiply by infinity
        a = POS_INF; b = TWO; #10;
        check(mul_result, POS_INF, "inf * 2.0 = inf");

        a = POS_INF; b = POS_ZERO; #10;
        check(mul_result, QNAN_PROP, "inf * 0.0 = NaN");

        // NaN
        a = SNAN; b = TWO; #10;
        check(mul_result, QNAN_PROP, "NaN * 2.0 = NaN (propagated)");

        // ===================== FPU DIV =====================
        $display("\n=== FPU DIV ===");

        // Basic division
        a = TEN; b = TWO; #10;
        check(div_result, FIVE, "10.0 / 2.0 = 5.0");

        a = SIX; b = THREE; #10;
        check(div_result, TWO, "6.0 / 3.0 = 2.0");

        a = ONE; b = ONE; #10;
        check(div_result, ONE, "1.0 / 1.0 = 1.0");

        a = FOUR; b = TWO; #10;
        check(div_result, TWO, "4.0 / 2.0 = 2.0");

        a = NEG_ONE; b = TWO; #10;
        check(div_result, 64'hBFE0000000000000, "-1.0 / 2.0 = -0.5");

        a = ONE; b = THREE; #10;
        // 1/3 = 0x3FD5555555555555
        check(div_result, 64'h3FD5555555555555, "1.0 / 3.0 (rounding)");

        a = ONE; b = TEN; #10;
        // 0.1 = 0x3FB999999999999A
        check(div_result, 64'h3FB999999999999A, "1.0 / 10.0 = 0.1 (rounding)");

        // Division by zero
        a = ONE; b = POS_ZERO; #10;
        check(div_result, QNAN_PROP, "1.0 / 0.0 = NaN");

        a = POS_ZERO; b = POS_ZERO; #10;
        check(div_result, QNAN_PROP, "0.0 / 0.0 = NaN");

        // Zero / nonzero
        a = POS_ZERO; b = FIVE; #10;
        check(div_result, POS_ZERO, "0.0 / 5.0 = 0.0");

        // Infinity
        a = POS_INF; b = TWO; #10;
        check(div_result, POS_INF, "inf / 2.0 = inf");

        a = POS_INF; b = POS_INF; #10;
        check(div_result, QNAN_GEN, "inf / inf = NaN (generated)");

        a = ONE; b = POS_INF; #10;
        check(div_result, POS_ZERO, "1.0 / inf = 0.0");

        a = POS_INF; b = POS_ZERO; #10;
        check(div_result, POS_INF, "inf / 0.0 = inf");

        // NaN
        a = SNAN; b = TWO; #10;
        check(div_result, QNAN_PROP, "NaN / 2.0 = NaN (propagated)");

        // ===================== SUMMARY =====================
        $display("\n============================================");
        $display("  FPU RESULTS: %0d passed, %0d failed out of %0d tests",
                 pass_count, fail_count, pass_count + fail_count);
        $display("============================================");
        $finish;
    end

endmodule
