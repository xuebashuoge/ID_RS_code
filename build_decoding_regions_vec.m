function [S, D_ratio, valid_symbols_uint32] = build_decoding_regions_vec(r, K, L, func_type, params)
    % build_decoding_regions_vec: Determines valid GF symbols at each position
    % (Optimized for memory and large n/L up to n=50)
    %
    % Inputs:
    %   r, K, L, func_type, params - Configuration
    %
    % Outputs:
    %   S - Hamming weight of the boolean function
    %   D_ratio - Ratio of valid symbols to total symbols in each decoding region [1 x L]
    %   valid_symbols_uint32 - Valid message symbols matrix [S x K] uint32

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
        valid_symbols_uint32 = zeros(0, K, 'uint32');
        return;
    end

    % Group bits into K blocks of length r for all S valid messages -> [S x K] uint32
    valid_symbols_uint32 = zeros(S, K, 'uint32');
    weights_sym = 2.^((r-1):-1:0);
    for k = 1:K
        idx = (k-1)*r + 1 : k*r;
        valid_symbols_uint32(:, k) = uint32(sum(valid_b_matrix(:, idx) .* weights_sym, 2));
    end

    % Compute D_ratio efficiently using chunking over L
    D_ratio = zeros(1, L);
    field_size = 2^r;

    if S == 1
        D_ratio(:) = 1 / field_size;
    else
        prim_poly = get_primpoly(r);
        eval_points = rs_evaluation_points(r, L, prim_poly);

        chunk_size = 2000;
        for c_start = 1:chunk_size:L
            c_end = min(c_start + chunk_size - 1, L);
            cols = c_start:c_end;
            num_cols = length(cols);

            x_chunk_pts = eval_points(cols); % [1 x num_cols] evaluation points for this chunk
            c_chunk = repmat(valid_symbols_uint32(:, K), 1, num_cols);
            for k = (K-1):-1:1
                c_chunk = bitxor(gf_mul_vec(c_chunk, x_chunk_pts, r, prim_poly), valid_symbols_uint32(:, k));
            end

            for idx = 1:num_cols
                D_ratio(cols(idx)) = length(unique(c_chunk(:, idx))) / field_size;
            end
        end
    end
end
