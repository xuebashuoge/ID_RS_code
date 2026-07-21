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
    
    % 2. Create Vandermonde matrix X [K x L] uint32
    % X(k, l) = alpha^(l * (k - 1)) in GF(2^r) where alpha = 2
    X = zeros(K, L, 'uint32');
    
    % Compute powers of alpha = 2 in GF(2^r)
    alpha = uint32(2);
    
    % alpha_powers(l) = alpha^l for l = 1..L
    alpha_powers = zeros(1, L, 'uint32');
    curr = uint32(1);
    for l = 1:L
        curr = gf_mul_vec(curr, alpha, r, prim_poly);
        alpha_powers(l) = curr;
    end
    
    for k = 1:K
        if k == 1
            X(1, :) = uint32(1);  % alpha^(l*0) = 1
        else
            % X(k, l) = alpha^(l * (k-1)) = (alpha^l)^(k-1)
            % Compute power k-1 of alpha_powers
            power_val = uint32(1);
            for p = 1:(k-1)
                power_val = gf_mul_vec(power_val, alpha_powers, r, prim_poly);
            end
            X(k, :) = power_val;
        end
    end
    
    % 3. Codewords c(n, l) = sum_{k=1}^K symbols(n, k) * X(k, l) in GF(2^r)
    c = zeros(N, L, 'uint32');
    for k = 1:K
        term = gf_mul_vec(symbols(:, k), X(k, :), r, prim_poly);
        c = bitxor(c, term);
    end
end