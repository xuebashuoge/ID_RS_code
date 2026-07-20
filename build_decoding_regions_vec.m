function [S, D_ratio, valid_c_matrix_uint32] = build_decoding_regions_vec(r, K, L, func_type, params)
    % build_decoding_regions_vec: Determines valid GF symbols at each position
    % (Optimized for memory and large n/L)
    %
    % Inputs:
    %   r, K, L, func_type, params - Configuration
    %
    % Outputs:
    %   S - Hamming weight of the boolean function
    %   D_ratio - Ratio of valid symbols to total symbols in each decoding region [1 x L]
    %   valid_c_matrix_uint32 - Valid codewords matrix [S x L] uint32

    m = r * K;  % Total message length in bits

    switch lower(func_type)
        case 'id'
            valid_b_matrix = params.target;
            S = 1;

        case 'exact-threshold'
            beta = params.beta;
            if beta > m
                valid_b_matrix = zeros(0, m);
                S = 0;
            elseif beta == 0
                valid_b_matrix = zeros(1, m);
                S = 1;
            else
                combos = nchoosek(1:m, beta);
                S = size(combos, 1);
                valid_b_matrix = zeros(S, m);
                for i = 1:S
                    valid_b_matrix(i, combos(i, :)) = 1;
                end
            end

        case 'at-most-threshold'
            beta = params.beta;
            beta = min(beta, m);

            S = 0;
            for j = 0:beta
                S = S + nchoosek(m, j);
            end

            valid_b_matrix = zeros(S, m);
            row = 1;

            % Weight 0
            row = row + 1;

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
        valid_c_matrix_uint32 = zeros(0, L, 'uint32');
        return;
    end

    % Encode valid messages to get codewords
    valid_c_matrix = rs_encode_polynomial_vec(valid_b_matrix, r, K, L);
    valid_c_matrix_uint32 = uint32(valid_c_matrix.x);

    % Compute D_ratio efficiently for each position l
    D_ratio = zeros(1, L);
    field_size = 2^r;
    
    % If S is small, computing unique length per column is very fast
    parfor l = 1:L
        D_ratio(l) = length(unique(valid_c_matrix_uint32(:, l))) / field_size;
    end
end