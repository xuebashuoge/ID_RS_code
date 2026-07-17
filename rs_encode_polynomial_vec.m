function c = rs_encode_polynomial_vec(b, r, K, L)
    % rs_encode_polynomial: Encodes messages into RS codewords (Vectorized)
    %
    % Inputs:
    %   b       - Binary matrix [N x (r*K)] representing N messages
    %   r       - GF(2^r) parameter
    %   K       - Number of symbols
    %   L       - Length of the codeword
    %
    % Output:
    %   c       - [N x L] Galois field array representing the codewords
    
    N = size(b, 1); % Number of messages/trials
    
    % 1. Group bits into K blocks of length r for all N messages
    symbols = zeros(N, K);
    weights = 2.^((r-1):-1:0);
    
    for k = 1:K
        idx = (k-1)*r + 1 : k*r;
        % Fast vectorized binary-to-decimal conversion
        symbols(:, k) = sum(b(:, idx) .* weights, 2);
    end
    
    % 2. Create polynomial coefficients in GF(2^r)
    P = gf(symbols, r); % Size: [N x K]
    
    % 3. Evaluate polynomial at primitive element powers
    % We only need to build the Vandermonde matrix X ONCE.
    alpha = gf(2, r);
    X = gf(zeros(K, L), r);
    for k = 1:K
        for l = 1:L
            % change to start from alpha^1 instead of alpha^0
            X(k, l) = alpha ^ (l * (k - 1));
        end
    end
    
    % 4. Codewords are computed via a single matrix multiplication
    % P is [N x K], X is [K x L]. Result is [N x L].
    c = P * X;
end