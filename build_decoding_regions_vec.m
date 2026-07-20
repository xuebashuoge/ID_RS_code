function [D, S, D_ratio] = build_decoding_regions_vec(r, K, L, func_type, params)
    % build_decoding_regions: Determines valid GF symbols at each position
    %
    % Inputs:
    %   r, K, L, func_type, params - Configuration
    %
    % Outputs:
    %   D - Cell array of size [1 x L]. D{l} contains a GF array of symbols
    %   S - Hamming weight of the boolean function
    %   D_ratio - Ratio of valid symbols to total symbols in each decoding region
    
    % Initialize D as empty Galois Field arrays
    D = cell(1, L);
    for l = 1:L
        D{l} = gf([], r);
    end

    m = r * K;  % Total message length in bits

    switch lower(func_type)
        case 'id'
            % For 'id', the only valid message is the target message itself
            valid_b_matrix = params.target;
            S = 1;

        case 'exact-threshold'
            % Pre-image: all binary vectors of length m with Hamming weight == beta
            % Generate directly via nchoosek instead of enumerating all 2^m messages
            beta = params.beta;
            if beta > m
                valid_b_matrix = zeros(0, m);
                S = 0;
            elseif beta == 0
                valid_b_matrix = zeros(1, m);
                S = 1;
            else
                combos = nchoosek(1:m, beta);  % Each row: indices of the 1-bits
                S = size(combos, 1);            % = C(m, beta)
                valid_b_matrix = zeros(S, m);
                for i = 1:S
                    valid_b_matrix(i, combos(i, :)) = 1;
                end
            end

        case 'at-most-threshold'
            % Pre-image: all binary vectors of length m with Hamming weight <= beta
            % Generate directly for each weight 0..beta via nchoosek
            beta = params.beta;
            beta = min(beta, m);  % Clamp to message length

            % Count total valid messages: sum of C(m, j) for j = 0..beta
            S = 0;
            for j = 0:beta
                S = S + nchoosek(m, j);
            end

            valid_b_matrix = zeros(S, m);
            row = 1;

            % Weight 0: the all-zeros vector
            row = row + 1;  % First row is already all zeros

            % Weights 1..beta
            for j = 1:beta
                combos = nchoosek(1:m, j);
                num_combos = size(combos, 1);
                for i = 1:num_combos
                    valid_b_matrix(row, combos(i, :)) = 1;
                    row = row + 1;
                end
            end

        case 'bit-query'
            % Pre-image: all binary vectors with bit t == 1
            % S = 2^(m-1), which can be very large
            S = 2^(m - 1);
            if S > 1e8
                error('Message space for bit-query (S=2^%d) is too large to enumerate.', m-1);
            end
            total_messages = 2^m;
            msg_ints = (0:(total_messages - 1))';
            weights_b = 2.^((m-1):-1:0);
            b_matrix = rem(floor(msg_ints ./ weights_b), 2);
            func_outputs = evaluate_boolean_function_vec(b_matrix, func_type, params);
            valid_b_matrix = b_matrix(func_outputs, :);
            S = size(valid_b_matrix, 1);

        case 'and-subset'
            % Pre-image: all binary vectors with all bits in S_k set to 1
            % S = 2^(m - |S_k|), which can be very large
            k_size = length(params.S_k);
            S = 2^(m - k_size);
            if S > 1e8
                error('Message space for and-subset (S=2^%d) is too large to enumerate.', m - k_size);
            end
            total_messages = 2^m;
            msg_ints = (0:(total_messages - 1))';
            weights_b = 2.^((m-1):-1:0);
            b_matrix = rem(floor(msg_ints ./ weights_b), 2);
            func_outputs = evaluate_boolean_function_vec(b_matrix, func_type, params);
            valid_b_matrix = b_matrix(func_outputs, :);
            S = size(valid_b_matrix, 1);

        case 'rank'
            % Pre-image: first rank+1 binary vectors (int(b) <= rank)
            S = params.rank + 1;
            if S > 1e8
                error('Message space for rank (S=%d) is too large to enumerate.', S);
            end
            msg_ints = (0:(S - 1))';
            weights_b = 2.^((m-1):-1:0);
            valid_b_matrix = rem(floor(msg_ints ./ weights_b), 2);

        otherwise
            error('Unknown boolean function type.');
    end

    % Handle edge case: no valid messages
    if S == 0
        D_ratio = zeros(1, L);
        return;
    end

    % Encode valid messages to get codewords
    valid_c_matrix = rs_encode_polynomial_vec(valid_b_matrix, r, K, L);

    % Add symbols to respective decoding regions
    D_ratio = zeros(1, L);
    for l = 1:L
        valid_c_ints = valid_c_matrix(:, l);
        unique_ints = unique(valid_c_ints.x);
        D{l} = gf(unique_ints, r);
        D_ratio(l) = size(unique_ints, 1) / 2^r;
    end
end