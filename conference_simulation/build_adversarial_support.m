function [negative_symbols, support_symbols, collision_positions] = ...
    build_adversarial_support(r, K, L, S)
%BUILD_ADVERSARIAL_SUPPORT Construct disjoint K-1 collision sets.
%
% For each positive polynomial q_s, q_s-p is a nonzero degree-(K-1)
% polynomial with a prescribed, disjoint set of K-1 roots. Therefore the
% fixed negative polynomial p collides on exactly S(K-1) positions.

    required_positions = S * (K - 1);
    if required_positions > L
        error('The construction requires S(K-1) <= L.');
    end

    prim_poly = get_primpoly(r);
    eval_points = rs_evaluation_points(r, L, prim_poly);
    negative_symbols = zeros(1, K, 'uint32');
    support_symbols = zeros(S, K, 'uint32');
    collision_positions = zeros(S, max(0, K - 1));

    for support_index = 1:S
        first_position = (support_index - 1) * (K - 1) + 1;
        last_position = support_index * (K - 1);
        positions = first_position:last_position;
        collision_positions(support_index, :) = positions;
        roots = eval_points(positions);
        difference = gf_polynomial_from_roots(roots, r, prim_poly);
        support_symbols(support_index, :) = bitxor( ...
            negative_symbols, difference);
    end

    if size(unique(support_symbols, 'rows'), 1) ~= S
        error('Adversarial construction unexpectedly produced duplicates.');
    end
    if any(all(support_symbols == negative_symbols, 2))
        error('The negative polynomial was included in the positive support.');
    end
end
