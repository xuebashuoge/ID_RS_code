function stat = run_monte_carlo_vec(valid_symbols_uint32, r, K, L, func_type, params, num_trials)
    % run_monte_carlo: Estimates Empirical FP and FN rates
    % Supports any r (1..32) without relying on MATLAB's built-in gf object.
    % Memory-optimized by computing sampled valid codewords on-the-fly.

    S = size(valid_symbols_uint32, 1);
    if S == 0
        stat = struct('fp_prob', 0, 'fn_prob', 0, 'error_prob', 0, ...
                      'fp_prob_baseline', 0, 'fn_prob_baseline', 0, ...
                      'error_prob_baseline', 0);
        return;
    end

    prim_poly = get_primpoly(r);

    % 1. Pre-compute evaluation points alpha_powers(l) = alpha^l for l = 1..L
    alpha = uint32(2);
    alpha_powers = zeros(1, L, 'uint32');
    curr = uint32(1);
    for l = 1:L
        curr = gf_mul_vec(curr, alpha, r, prim_poly);
        alpha_powers(l) = curr;
    end

    % 2. Convert target to symbol format once if func_type is 'id'
    if strcmpi(func_type, 'id')
        target_symbols = zeros(1, K, 'uint32');
        weights = 2.^((r-1):-1:0);
        for k = 1:K
            idx = (k-1)*r + 1 : k*r;
            target_symbols(k) = uint32(sum(params.target(idx) .* weights));
        end
    else
        target_symbols = [];
    end

    % 3. Batch Loop setup with dynamic batch size to constrain peak worker memory
    field_size = 2^r;
    batch_size = min(50000, max(1000, floor(1e8 / max(1, S))));
    num_batches = ceil(num_trials / batch_size);

    total_fp = 0;
    total_fn = 0;
    total_fp_baseline = 0;
    total_fn_baseline = 0;

    parfor b = 1:num_batches
        curr_batch_size = min(batch_size, num_trials - (b - 1) * batch_size);

        if strcmpi(func_type, 'id')
            symbols = uint32(randi([0, field_size - 1], curr_batch_size, K));
            actual_f = all(bsxfun(@eq, symbols, target_symbols), 2);
        else
            b_matrix = randi([0, 1], curr_batch_size, r*K);
            actual_f = evaluate_boolean_function_vec(b_matrix, func_type, params);

            symbols = zeros(curr_batch_size, K, 'uint32');
            weights_sym = 2.^((r-1):-1:0);
            for k = 1:K
                idx = (k-1)*r + 1 : k*r;
                symbols(:, k) = uint32(sum(b_matrix(:, idx) .* weights_sym, 2));
            end
        end

        % Choose uniform indices U from {1...L} for each trial in the batch
        U = randi([1, L], curr_batch_size, 1);
        x_val = alpha_powers(U)'; % [curr_batch_size x 1] evaluation points

        % Compute received symbol Y_i in GF(2^r) using Horner's method
        received_symbols_x = symbols(:, K);
        for k = (K-1):-1:1
            received_symbols_x = bitxor(gf_mul_vec(received_symbols_x, x_val, r, prim_poly), symbols(:, k));
        end

        % Group sampled channel positions to evaluate valid symbols ONCE per unique position
        [u_unique, ~, u_map] = unique(U);
        num_u = length(u_unique);
        x_u_pts = alpha_powers(u_unique); % [1 x num_u] evaluation points

        % Compute valid codeword symbols for the unique evaluation points: [S x num_u]
        C_valid_u = repmat(valid_symbols_uint32(:, K), 1, num_u);
        for k = (K-1):-1:1
            C_valid_u = bitxor(gf_mul_vec(C_valid_u, x_u_pts, r, prim_poly), valid_symbols_uint32(:, k));
        end

        % Fast membership check: test if received_symbols_x(i) belongs to unique valid symbols for position U_i
        decoded_f = false(curr_batch_size, 1);
        for u_idx = 1:num_u
            trial_mask = (u_map == u_idx);
            valid_set_idx = unique(C_valid_u(:, u_idx));
            decoded_f = decoded_f | (trial_mask & ismember(received_symbols_x, valid_set_idx));
        end

        decoded_f_baseline = false(curr_batch_size, 1);

        % Tally metrics
        fp_count = sum((actual_f == 0) & (decoded_f == 1));
        fn_count = sum((actual_f == 1) & (decoded_f == 0));
        fp_count_baseline = sum((actual_f == 0) & (decoded_f_baseline == 1));
        fn_count_baseline = sum((actual_f == 1) & (decoded_f_baseline == 0));

        total_fp = total_fp + fp_count;
        total_fn = total_fn + fn_count;
        total_fp_baseline = total_fp_baseline + fp_count_baseline;
        total_fn_baseline = total_fn_baseline + fn_count_baseline;
    end

    % Calculate final conditional probabilities
    fp_prob = total_fp / num_trials;
    fn_prob = total_fn / num_trials;
    error_prob = (total_fp + total_fn) / num_trials;
    
    fp_prob_baseline = total_fp_baseline / num_trials;
    fn_prob_baseline = total_fn_baseline / num_trials;
    error_prob_baseline = (total_fp_baseline + total_fn_baseline) / num_trials;
    
    stat = struct('fp_prob', fp_prob, 'fn_prob', fn_prob, 'error_prob', error_prob, ...
                  'fp_prob_baseline', fp_prob_baseline, 'fn_prob_baseline', fn_prob_baseline, ...
                  'error_prob_baseline', error_prob_baseline);
end