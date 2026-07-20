function stat = run_monte_carlo_vec(valid_c_matrix_uint32, r, K, L, func_type, params, num_trials)
    % run_monte_carlo: Estimates Empirical FP and FN rates
    % Optimized for huge n (evaluates RS polynomial ONLY at position U_i per trial,
    % avoiding massive N x L matrix allocations and giant lookup tables).

    S = size(valid_c_matrix_uint32, 1);
    if S == 0
        stat = struct('fp_prob', 0, 'fn_prob', 0, 'error_prob', 0, ...
                      'fp_prob_baseline', 0, 'fn_prob_baseline', 0, ...
                      'error_prob_baseline', 0);
        return;
    end

    % 1. Pre-build the Vandermonde matrix X_raw [K x L] uint32
    alpha = gf(2, r);
    X = gf(zeros(K, L), r);
    for k = 1:K
        for l = 1:L
            X(k, l) = alpha ^ (l * (k - 1));
        end
    end
    X_raw = uint32(X.x);  % [K x L] uint32

    % 2. Convert target to symbol format once if func_type is 'id'
    if strcmpi(func_type, 'id')
        target_symbols = zeros(1, K);
        weights = 2.^((r-1):-1:0);
        for k = 1:K
            idx = (k-1)*r + 1 : k*r;
            target_symbols(k) = sum(params.target(idx) .* weights);
        end
    else
        target_symbols = [];
    end

    % 3. Batch Loop setup
    field_size = 2^r;
    batch_size = 100000; % process 10^5 trials at a time
    num_batches = ceil(num_trials / batch_size);

    total_fp = 0;
    total_fn = 0;
    total_fp_baseline = 0;
    total_fn_baseline = 0;

    parfor b = 1:num_batches
        curr_batch_size = min(batch_size, num_trials - (b - 1) * batch_size);

        if strcmpi(func_type, 'id')
            symbols = randi([0, field_size - 1], curr_batch_size, K);
            actual_f = all(bsxfun(@eq, symbols, target_symbols), 2);
        else
            b_matrix = randi([0, 1], curr_batch_size, r*K);
            actual_f = evaluate_boolean_function_vec(b_matrix, func_type, params);

            symbols = zeros(curr_batch_size, K);
            weights_sym = 2.^((r-1):-1:0);
            for k = 1:K
                idx = (k-1)*r + 1 : k*r;
                symbols(:, k) = sum(b_matrix(:, idx) .* weights_sym, 2);
            end
        end

        % Choose uniform indices U from {1...L} for each trial in the batch
        U = randi([1, L], curr_batch_size, 1);

        % Evaluate RS polynomial ONLY at the single selected channel position U_i for each trial
        % x_eval is [K x curr_batch_size] containing evaluation factors alpha^(U_i*(k-1))
        x_eval = X_raw(:, U);

        % Compute received symbol Y_i in GF(2^r) for each trial
        rec_gf = gf(zeros(curr_batch_size, 1), r);
        for k = 1:K
            rec_gf = rec_gf + gf(symbols(:, k), r) .* gf(x_eval(k, :)', r);
        end
        received_symbols_x = uint32(rec_gf.x);  % [curr_batch_size x 1] uint32

        % Check if received symbol matches ANY valid codeword symbol at position U_i
        % C_valid_sampled is [S x curr_batch_size] uint32
        C_valid_sampled = valid_c_matrix_uint32(:, U);

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