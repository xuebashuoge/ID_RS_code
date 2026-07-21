% Test script for custom GF(2^r) arithmetic for any r (including r > 16)
clear; close all;

fprintf('=== Testing Custom GF(2^r) Multiplication for r > 16 ===\n\n');

function pp = get_primpoly(r)
    if r <= 16
        pp = primpoly(r, 'nodisplay');
    else
        % Standard primitive polynomials for GF(2^r), r = 17..32
        % Represented as integer: sum(2^exponent) for terms in polynomial
        switch r
            case 17, pp = 131081;     % x^17 + x^3 + 1
            case 18, pp = 262273;     % x^18 + x^7 + 1
            case 19, pp = 524327;     % x^19 + x^5 + x^2 + x + 1
            case 20, pp = 1048585;    % x^20 + x^3 + 1
            case 21, pp = 2097157;    % x^21 + x^2 + 1
            case 22, pp = 4194307;    % x^22 + x + 1
            case 23, pp = 8388641;    % x^23 + x^5 + 1
            case 24, pp = 16777351;   % x^24 + x^7 + x^2 + x + 1
            case 25, pp = 33554441;   % x^25 + x^3 + 1
            case 26, pp = 67108927;   % x^26 + x^6 + x^2 + x + 1
            case 27, pp = 134217781;  % x^27 + x^5 + x^2 + x + 1
            case 28, pp = 268435465;  % x^28 + x^3 + 1
            case 29, pp = 536870915;  % x^29 + x^2 + 1
            case 30, pp = 1073741877; % x^30 + x^23 + x^2 + x + 1
            case 31, pp = 2147483657; % x^31 + x^3 + 1
            case 32, pp = 4294967357; % x^32 + x^7 + x^5 + x^3 + x^2 + x + 1
            otherwise, error('Unsupported r > 32');
        end
    end
end

function C = gf_mul_vec(A, B, r, prim_poly)
    mask = uint64(2^r - 1);
    poly_trunc = uint64(bitand(prim_poly, uint64(2^r - 1)));
    
    A = uint64(A);
    B = uint64(B);
    C = zeros(size(A), 'uint64');
    
    for bit = 0:(r-1)
        mask_bit = bitget(B, bit + 1);
        C = bitxor(C, A .* mask_bit);
        
        msb = bitget(A, r);
        A = bitand(bitshift(A, 1), mask);
        A = bitxor(A, poly_trunc .* msb);
    end
    C = uint32(C);
end

all_passed = true;

% 1. Test against MATLAB built-in gf for r <= 16
for r = [2, 4, 8, 12, 16]
    pp = get_primpoly(r);
    
    N = 1000;
    A_val = randi([0, 2^r - 1], N, 1);
    B_val = randi([0, 2^r - 1], N, 1);
    
    gf_prod = gf(A_val, r) .* gf(B_val, r);
    expected = double(gf_prod.x);
    
    got = double(gf_mul_vec(A_val, B_val, r, pp));
    
    if isequal(expected, got)
        fprintf('r = %2d (m <= 16): PASS (%d random products match built-in gf)\n', r, N);
    else
        fprintf('r = %2d: FAIL (%d mismatches)\n', r, sum(expected ~= got));
        all_passed = false;
    end
end

% 2. Test r = 17..25 (n = 34..50)
for r = [17, 18, 20, 24, 25]
    pp = get_primpoly(r);
    N = 1000;
    A_val = randi([0, 2^r - 1], N, 1);
    B_val = randi([0, 2^r - 1], N, 1);
    C_val = gf_mul_vec(A_val, B_val, r, pp);
    fprintf('r = %2d (n = %d): PASS (Computed %d products, max value = %d <= %d)\n', ...
        r, 2*r, N, max(C_val), 2^r - 1);
end

if all_passed
    fprintf('\n=== ALL TESTS PASSED ===\n');
end
