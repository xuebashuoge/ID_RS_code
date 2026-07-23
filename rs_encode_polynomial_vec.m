function c = rs_encode_polynomial_vec(b, r, K, L)
    % rs_encode_polynomial: Encodes messages into RS codewords (Vectorized)
    % Supports any r (1..32) without relying on MATLAB's built-in gf object.
    %
    % Inputs:
    %   b       - Binary matrix [N x (r*K)] representing N messages
    %   r       - GF(2^r) parameter
    %   K       - Number of symbols
    %   L       - Length of the codeword
    %
    % Output:
    %   c       - [N x L] uint32 matrix representing codeword symbols
    
    N = size(b, 1);
    prim_poly = get_primpoly(r);
    
    % 1. Group bits into K blocks of length r for all N messages
    symbols = zeros(N, K, 'uint32');
    weights = 2.^((r-1):-1:0);
    
    for k = 1:K
        idx = (k-1)*r + 1 : k*r;
        symbols(:, k) = uint32(sum(b(:, idx) .* weights, 2));
    end
    
    % 2. Compute evaluation points alpha_powers(l) = alpha^l in GF(2^r) for l = 1..L
    alpha = uint32(2);
    alpha_powers = zeros(1, L, 'uint32');
    curr = uint32(1);
    for l = 1:L
        curr = gf_mul_vec(curr, alpha, r, prim_poly);
        alpha_powers(l) = curr;
    end
    
    % 3. Evaluate polynomial using Horner's method: c = ( ... (s_K * x + s_{K-1}) * x ... + s_1)
    c = repmat(symbols(:, K), 1, L);
    for k = (K-1):-1:1
        c = bitxor(gf_mul_vec(c, alpha_powers, r, prim_poly), symbols(:, k));
    end
end