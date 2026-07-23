function [D, S, D_ratio] = build_decoding_regions_bruteforce(r, K, L, func_type, params)
    % build_decoding_regions_bruteforce: Reference brute-force implementation
    % for verification. Enumerates all 2^m messages and filters.
    %
    % Only works for small m (m <= ~26 due to memory).

    D = cell(1, L);
    for l = 1:L
        D{l} = gf([], r);
    end

    if strcmpi(func_type, 'id')
        valid_b_matrix = params.target;
        S = 1;
    else
        total_messages = 2^(r * K);
        msg_ints = (0:(total_messages - 1))';
        weights_b = 2.^((r*K-1):-1:0);
        b_matrix = rem(floor(msg_ints ./ weights_b), 2);
        func_outputs = evaluate_boolean_function_vec(b_matrix, func_type, params);
        valid_b_matrix = b_matrix(func_outputs, :);
        S = size(valid_b_matrix, 1);
    end

    % Handle edge case: no valid messages
    if S == 0
        D_ratio = zeros(1, L);
        return;
    end

    valid_c_matrix = rs_encode_polynomial_vec(valid_b_matrix, r, K, L);

    D_ratio = zeros(1, L);
    for l = 1:L
        valid_c_ints = valid_c_matrix(:, l);
        unique_ints = unique(valid_c_ints);
        D{l} = unique_ints;
        D_ratio(l) = size(unique_ints, 1) / 2^r;
    end
end
