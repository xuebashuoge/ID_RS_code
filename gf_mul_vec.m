function C = gf_mul_vec(A, B, r, prim_poly)
    % gf_mul_vec: Fast Galois Field GF(2^r) multiplication for any r (1..32).
    % Supports scalar, vector, or matrix inputs with broadcasting.
    %
    % Inputs:
    %   A, B      - Integer arrays with values in [0, 2^r - 1]
    %   r         - Field extension degree (e.g. 17 for GF(2^17))
    %   prim_poly - Primitive polynomial integer (e.g. from get_primpoly(r))
    %
    % Output:
    %   C         - uint32 result array of GF multiplication

    mask = uint64(2^r - 1);
    poly_trunc = uint64(bitand(prim_poly, uint64(2^r - 1)));

    A = uint64(A);
    B = uint64(B);
    
    % Allocate output C with implicit size broadcasting between A and B
    C = zeros(max(size(A,1), size(B,1)), max(size(A,2), size(B,2)), 'uint64');

    for bit = 0:(r-1)
        mask_bit = bitget(B, bit + 1);
        C = bitxor(C, A .* mask_bit);

        msb = bitget(A, r);
        A = bitand(bitshift(A, 1), mask);
        A = bitxor(A, poly_trunc .* msb);
    end

    C = uint32(C);
end
