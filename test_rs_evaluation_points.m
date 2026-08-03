% Regression tests for distinct extended-RS evaluation points.
clear;

r = 2;
K = 3;
L = 2^r;
prim_poly = get_primpoly(r);

eval_points = rs_evaluation_points(r, L, prim_poly);
assert(isequal(eval_points, uint32([0, 1, 2, 3])));
assert(numel(unique(eval_points)) == L);

% Messages 120 and 302 over GF(4), represented as big-endian bit blocks.
messages = [0, 1, 1, 0, 0, 0; ...
            1, 1, 0, 0, 1, 0];
codewords = rs_encode_polynomial_vec(messages, r, K, L);
assert(isequal(codewords(1, :), uint32([1, 3, 2, 0])));
assert(isequal(codewords(2, :), uint32([3, 1, 2, 0])));
assert(sum(codewords(1, :) == codewords(2, :)) == K - 1);

% The fixed-message Monte Carlo path must use the same corrected encoding.
fixed_symbols = uint32([1, 2, 0]);
valid_symbols = uint32([3, 0, 2]);
stat = run_monte_carlo_fixed_msg_vec( ...
    fixed_symbols, valid_symbols, r, K, L, 'id', struct(), 1000);
assert(stat.R == K - 1);
assert(stat.fp_prob_exact == (K - 1) / L);

% Exhaustively verify the pairwise RS agreement bound over all GF(4)^3 messages.
all_messages = zeros(2^(r*K), r*K);
for msg = 0:(2^(r*K) - 1)
    all_messages(msg + 1, :) = bitget(uint32(msg), (r*K):-1:1);
end
all_codewords = rs_encode_polynomial_vec(all_messages, r, K, L);

for i = 1:(size(all_codewords, 1) - 1)
    agreements = sum(all_codewords((i + 1):end, :) == all_codewords(i, :), 2);
    assert(all(agreements <= K - 1));
end

fprintf('RS evaluation-point regression tests passed.\n');
