module fpu_class(input [63:0] f, output nan, output infinity, output zero, output subnormal, output normal);
    wire expOnes  = &f[62:52];
    wire expZero  = ~|f[62:52];
    wire fracZero = ~|f[51:0];
    assign nan       = expOnes  & ~fracZero;
    assign infinity  = expOnes  &  fracZero;
    assign zero      = expZero  &  fracZero;
    assign subnormal = expZero  & ~fracZero;
    assign normal    = ~expOnes & ~expZero;
endmodule

module fpu_mul(input [63:0] a, input [63:0] b, output reg [63:0] result);
    wire aNan, aInf, aZero, aSubnormal, aNormal;
    wire bNan, bInf, bZero, bSubnormal, bNormal;
    fpu_class classA(.f(a), .nan(aNan), .infinity(aInf), .zero(aZero), .subnormal(aSubnormal), .normal(aNormal));
    fpu_class classB(.f(b), .nan(bNan), .infinity(bInf), .zero(bZero), .subnormal(bSubnormal), .normal(bNormal));

    function [5:0] count_leading_zeros;
        input [52:0] sig;
        integer i;
        begin : clz_loop
            count_leading_zeros = 0;
            for (i = 52; i >= 0; i = i - 1) begin
                if (sig[i]) disable clz_loop;
                else count_leading_zeros = count_leading_zeros + 1;
            end
        end
    endfunction

    reg sign;
    reg signed [12:0] expA, expB, expResult, shiftAmount;
    reg [52:0] sigA, sigB, sigFinal;
    reg [105:0] sigResult;
    reg [5:0] shift;
    reg guard, round_bit, sticky;

    always @(*) begin
        sign = a[63] ^ b[63];
        if (aNan | bNan | (aInf & bZero) | (bInf & aZero)) begin
            result = 64'h7ff8000000000000;
        end else if (aInf | bInf) begin
            result = {sign, 11'h7ff, 52'h0};
        end else if (aZero | bZero) begin
            result = {sign, 63'h0};
        end else begin
            sigA = {aNormal, a[51:0]};
            sigB = {bNormal, b[51:0]};
            if (aNormal) expA = $signed({1'b0, a[62:52]}) - 1023;
            else begin shift = count_leading_zeros(sigA); sigA = sigA << shift; expA = -1022 - $signed({7'b0, shift}); end
            if (bNormal) expB = $signed({1'b0, b[62:52]}) - 1023;
            else begin shift = count_leading_zeros(sigB); sigB = sigB << shift; expB = -1022 - $signed({7'b0, shift}); end

            expResult = expA + expB + 1023;
            sigResult = sigA * sigB;
            if (sigResult[105]) begin expResult = expResult + 1; sigResult = sigResult >> 1; end

            sigFinal = sigResult[104:52];
            guard = sigResult[51]; round_bit = sigResult[50]; sticky = |sigResult[49:0];
            if (guard & (round_bit | sigFinal[0] | sticky)) begin
                sigFinal = sigFinal + 1;
                if (sigFinal == 53'h20000000000000) begin expResult = expResult + 1; sigFinal = 53'h10000000000000; end
            end

            if (expResult >= 2047) result = {sign, 11'h7ff, 52'h0};
            else if (expResult <= 0) begin
                shiftAmount = 1 - expResult;
                if (shiftAmount < 53) begin sigFinal = sigFinal >> shiftAmount; result = {sign, 11'h0, sigFinal[51:0]}; end
                else result = {sign, 63'h0};
            end else result = {sign, expResult[10:0], sigFinal[51:0]};
        end
    end
endmodule

module fpu_add(input [63:0] a, input [63:0] b, output reg [63:0] result);
    wire aNan, aInf, aZero, aSubnormal, aNormal;
    wire bNan, bInf, bZero, bSubnormal, bNormal;
    fpu_class classA(.f(a), .nan(aNan), .infinity(aInf), .zero(aZero), .subnormal(aSubnormal), .normal(aNormal));
    fpu_class classB(.f(b), .nan(bNan), .infinity(bInf), .zero(bZero), .subnormal(bSubnormal), .normal(bNormal));

    function [5:0] count_leading_zeros;
        input [55:0] sig;
        integer i;
        begin : clz_loop
            count_leading_zeros = 0;
            for (i = 55; i >= 0; i = i - 1) begin
                if (sig[i]) disable clz_loop;
                else count_leading_zeros = count_leading_zeros + 1;
            end
        end
    endfunction

    reg [52:0] augendSig, addendSig;
    reg signed [12:0] shift, expResult;
    reg sign;
    reg guard, round_bit, sticky;
    reg [55:0] extAugend, extAddend;
    reg [52:0] sigFinal;
    reg [56:0] sumSig, diffSig;
    reg [5:0] shiftAmount;
    reg signed [12:0] expA, expB;

    always @(*) begin
        if (aNan | bNan) begin
            result = 64'h7ff8000000000000;
        end else if (aInf & bInf) begin
            if (a[63] == b[63]) result = a;
            else result = {1'b1, 11'h7ff, 1'b1, 51'h0};
        end else if (aInf) begin
            result = a;
        end else if (bInf) begin
            result = b;
        end else if (aZero & bZero) begin
            result = {(a[63] & b[63]), 63'h0};
        end else if (aZero) begin
            result = b;
        end else if (bZero) begin
            result = a;
        end else begin
            expA = aNormal ? $signed({1'b0, a[62:52]}) : 13'd1;
            expB = bNormal ? $signed({1'b0, b[62:52]}) : 13'd1;

            augendSig = 0; addendSig = 0; sign = 0; shift = 0; expResult = 0;

            if (expA > expB) begin
                augendSig = {aNormal, a[51:0]}; addendSig = {bNormal, b[51:0]};
                sign = a[63]; expResult = expA; shift = expA - expB;
            end else if (expA < expB) begin
                augendSig = {bNormal, b[51:0]}; addendSig = {aNormal, a[51:0]};
                sign = b[63]; expResult = expB; shift = expB - expA;
            end else begin
                shift = 0; expResult = expA;
                if (a[63] == b[63]) begin
                    sign = a[63]; augendSig = {aNormal, a[51:0]}; addendSig = {bNormal, b[51:0]};
                end else begin
                    if (a[51:0] > b[51:0]) begin sign = a[63]; augendSig = {aNormal, a[51:0]}; addendSig = {bNormal, b[51:0]};
                    end else if (a[51:0] < b[51:0]) begin sign = b[63]; augendSig = {bNormal, b[51:0]}; addendSig = {aNormal, a[51:0]};
                    end else begin sign = 0; augendSig = {aNormal, a[51:0]}; addendSig = {bNormal, b[51:0]}; end
                end
            end

            extAugend = {augendSig, 3'b0};
            extAddend = {addendSig, 3'b0};
            if (shift == 0) sticky = 0;
            else if (shift >= 56) sticky = |extAddend;
            else sticky = |(extAddend << (56 - shift));
            if (shift >= 56) extAddend = 0;
            else extAddend = extAddend >> shift;

            if (a[63] == b[63]) begin
                sumSig = {1'b0, extAugend} + {1'b0, extAddend};
                if (sumSig[56]) begin expResult = expResult + 1; sticky = sticky | sumSig[0]; sumSig = sumSig >> 1; end

                guard = sumSig[2]; round_bit = sumSig[1]; sticky = sticky | sumSig[0];
                sigFinal = sumSig[55:3];
                if (guard & (round_bit | sigFinal[0] | sticky)) begin
                    sigFinal = sigFinal + 1;
                    if (sigFinal == 53'h20000000000000) begin expResult = expResult + 1; sigFinal = 53'h10000000000000; end
                end

                // Check if result is actually subnormal (no leading 1)
                if (sigFinal[52] == 0 && expResult == 1) expResult = 0;

                if (expResult >= 2047) result = {sign, 11'h7ff, 52'h0};
                else if (expResult <= 0) result = {sign, 11'h0, sigFinal[51:0]};
                else result = {sign, expResult[10:0], sigFinal[51:0]};
            end else begin
                diffSig = {1'b0, extAugend} - {1'b0, extAddend};
                if (diffSig == 0) result = 64'h0000000000000000;
                else begin
                    shiftAmount = count_leading_zeros(diffSig[55:0]);
                    if ($signed({7'b0, shiftAmount}) < expResult) begin
                        expResult = expResult - $signed({7'b0, shiftAmount});
                        diffSig = diffSig << shiftAmount;
                    end else begin
                        if (expResult > 1) diffSig = diffSig << (expResult - 1);
                        expResult = 0;
                    end

                    guard = diffSig[2]; round_bit = diffSig[1]; sticky = sticky | diffSig[0];
                    sigFinal = diffSig[55:3];
                    if (guard & (round_bit | sigFinal[0] | sticky)) begin
                        sigFinal = sigFinal + 1;
                        if (sigFinal == 53'h20000000000000) begin expResult = expResult + 1; sigFinal = 53'h10000000000000; end
                    end

                    if (sigFinal[52] == 0 && expResult == 1) expResult = 0;

                    if (expResult >= 2047) result = {sign, 11'h7ff, 52'h0};
                    else if (expResult <= 0) result = {sign, 11'h0, sigFinal[51:0]};
                    else result = {sign, expResult[10:0], sigFinal[51:0]};
                end
            end
        end
    end
endmodule

module fpu_div(input [63:0] a, input [63:0] b, output reg [63:0] result);
    wire aNan, aInf, aZero, aSubnormal, aNormal;
    wire bNan, bInf, bZero, bSubnormal, bNormal;
    fpu_class classA(.f(a), .nan(aNan), .infinity(aInf), .zero(aZero), .subnormal(aSubnormal), .normal(aNormal));
    fpu_class classB(.f(b), .nan(bNan), .infinity(bInf), .zero(bZero), .subnormal(bSubnormal), .normal(bNormal));

    function [5:0] count_leading_zeros;
        input [52:0] sig;
        integer i;
        begin : clz_loop
            count_leading_zeros = 0;
            for (i = 52; i >= 0; i = i - 1) begin
                if (sig[i]) disable clz_loop;
                else count_leading_zeros = count_leading_zeros + 1;
            end
        end
    endfunction

    reg sign;
    reg signed [12:0] expA, expB, expResult, shiftAmount;
    reg [52:0] sigA, sigB, sigFinal;
    reg [55:0] q;
    reg [109:0] dividend;
    reg [109:0] rem;
    reg [5:0] shift;
    reg guard, round_bit, sticky;
    integer i;

    always @(*) begin
        sign = a[63] ^ b[63];
        if (aNan | bNan) begin
            result = 64'h7ff8000000000000;
        end else if (aInf & bInf) begin
            result = {1'b1, 11'h7ff, 1'b1, 51'h0};
        end else if (aInf) begin
            result = {sign, 11'h7ff, 52'h0};
        end else if (bZero) begin
            result = 64'h7ff8000000000000;
        end else if (aZero) begin
            result = {sign, 63'h0};
        end else if (bInf) begin
            result = {sign, 63'h0};
        end else begin
            sigA = {aNormal, a[51:0]};
            sigB = {bNormal, b[51:0]};
            if (aNormal) expA = $signed({1'b0, a[62:52]}) - 1023;
            else begin shift = count_leading_zeros(sigA); sigA = sigA << shift; expA = -1022 - $signed({7'b0, shift}); end
            if (bNormal) expB = $signed({1'b0, b[62:52]}) - 1023;
            else begin shift = count_leading_zeros(sigB); sigB = sigB << shift; expB = -1022 - $signed({7'b0, shift}); end

            expResult = expA - expB + 1023;

            // 110-bit dividend: sigA at bits [107:55], zeros below
            dividend = {2'b0, sigA, 55'b0};
            rem = 0;
            q = 0;
            for (i = 109; i >= 0; i = i - 1) begin
                rem = (rem << 1) | {{109{1'b0}}, dividend[i]};
                if (rem >= {57'b0, sigB}) begin
                    rem = rem - {57'b0, sigB};
                    if (i < 56) q[i] = 1;
                end
            end

            // Normalize: if sigA < sigB, leading 1 is at bit 54
            if (!q[55]) begin
                expResult = expResult - 1;
                q = q << 1;
                // Get one more bit from remainder
                rem = rem << 1;
                if (rem >= {57'b0, sigB}) begin
                    q[0] = 1;
                    rem = rem - {57'b0, sigB};
                end
            end

            sigFinal = q[55:3];

            if (expResult >= 2047) begin
                result = {sign, 11'h7ff, 52'h0};
            end else if (expResult <= 0) begin
                shiftAmount = 1 - expResult;
                if (shiftAmount < 56) begin
                    // Re-round after subnormal shift using the full quotient
                    begin : subnorm_div_block
                        reg [56:0] q_shifted;
                        reg [56:0] shifted_out_mask;
                        reg sub_guard, sub_round, sub_sticky;
                        integer si;
                        
                        // Compute sticky from all bits that will be shifted out
                        sub_sticky = (rem != 0);
                        for (si = 0; si < shiftAmount && si < 56; si = si + 1)
                            sub_sticky = sub_sticky | q[si];
                        
                        q_shifted = q >> shiftAmount;
                        sub_guard = q_shifted[2];
                        sub_round = q_shifted[1];
                        sub_sticky = sub_sticky | q_shifted[0];
                        sigFinal = q_shifted[55:3];
                        
                        if (sub_guard & (sub_round | sigFinal[0] | sub_sticky))
                            sigFinal = sigFinal + 1;
                    end
                    result = {sign, 11'h0, sigFinal[51:0]};
                end else begin
                    result = {sign, 63'h0};
                end
            end else begin
                // Normal result: apply standard rounding
                guard = q[2];
                round_bit = q[1];
                sticky = q[0] | (rem != 0);
                if (guard & (round_bit | sigFinal[0] | sticky)) begin
                    sigFinal = sigFinal + 1;
                    if (sigFinal == 53'h20000000000000) begin expResult = expResult + 1; sigFinal = 53'h10000000000000; end
                end
                if (expResult >= 2047) result = {sign, 11'h7ff, 52'h0};
                else result = {sign, expResult[10:0], sigFinal[51:0]};
            end
        end
    end
endmodule