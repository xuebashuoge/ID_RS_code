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

    % 1. Pre-build the Vandermonde matrix X_raw [K x L] uint32
    % X(k, l) = alpha^(l * (k - 1)) in GF(2^r) where alpha = 2
    X_raw = zeros(K, L, 'uint32');
    alpha = uint32(2);
    alpha_powers = zeros(1, L, 'uint32');
    curr = uint32(1);
    for l = 1:L
        curr = gf_mul_vec(curr, alpha, r, prim_poly);
        alpha_powers(l) = curr;
    end
    for k = 1:K
        if k == 1
            X_raw(1, :) = uint32(1);
        else
            power_val = uint32(1);
            for p = 1:(k-1)
                power_val = gf_mul_vec(power_val, alpha_powers, r, prim_poly);
            end
            X_raw(k, :) = power_val;
        end
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

        % Evaluate RS polynomial ONLY at the single selected channel position U_i for each trial
        x_eval = X_raw(:, U);  % [K x curr_batch_size] uint32

        % Compute received symbol Y_i in GF(2^r) for each trial
        received_symbols_x = zeros(curr_batch_size, 1, 'uint32');
        for k = 1:K
            term_k = gf_mul_vec(symbols(:, k), x_eval(k, :)', r, prim_poly);
            received_symbols_x = bitxor(received_symbols_x, term_k);
        end

        % Compute valid codeword symbols at position U_i on-the-fly: [S x curr_batch_size]
        C_valid_sampled = zeros(S, curr_batch_size, 'uint32');
        for k = 1:K
            term_k = gf_mul_vec(valid_symbols_uint32(:, k), x_eval(k, :), r, prim_poly);
            C_valid_sampled = bitxor(C_valid_sampled, term_k);
        end

        % decoded_f(i) is true if received_symbols_x(i) matches C_valid_sampled(s, i) for any s=1..S
        decoded_f = any(bsxfun(@eq, received_symbols_x', C_valid_sampled), 1)';

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