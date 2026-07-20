function stat = run_monte_carlo_vec(D, r, K, L, func_type, params, num_trials)
    % run_monte_carlo: Estimates Empirical FP and FN rates (Vectorized)
    
    % 1. Pre-build the Vandermonde matrix X once to speed up batched RS encoding
    alpha = gf(2, r);
    X = gf(zeros(K, L), r);
    for k = 1:K
        for l = 1:L
            X(k, l) = alpha ^ (l * (k - 1));
        end
    end

    % 2. Receiver Decodes (Vectorized Lookup)
    % Instead of `ismember` in a loop, pre-build a fast logical lookup table.
    % valid_lookup(l, val+1) is true if symbol 'val' is valid at position 'l'
    valid_lookup = false(L, 2^r);
    for l = 1:L
        if ~isempty(D{l})
            % Add 1 to .x values because MATLAB is 1-indexed (GF vals are 0 to 2^r-1)
            valid_lookup(l, D{l}.x + 1) = true; 
        end
    end

    % 3. Convert target to symbol format once if func_type is 'id'
    if strcmpi(func_type, 'id')
        target_symbols = zeros(1, K);
        weights = 2.^((r-1):-1:0);
        for k = 1:K
            idx = (k-1)*r + 1 : k*r;
            target_symbols(k) = sum(params.target(idx) .* weights);
        end
    end

    % 4. Batch Loop setup
    batch_size = 100000; % process 10^5 trials at a time to save memory
    num_batches = ceil(num_trials / batch_size);

    total_fp = 0;
    total_fn = 0;
    total_fp_baseline = 0;
    total_fn_baseline = 0;

    for b = 1:num_batches
        % Determine current batch size
        curr_batch_size = min(batch_size, num_trials - (b - 1) * batch_size);

        if strcmpi(func_type, 'id')
            % Generate random messages directly as symbols in GF(2^r) to avoid huge binary matrix allocation
            symbols = randi([0, 2^r - 1], curr_batch_size, K);
            P = gf(symbols, r);
            actual_f = all(bsxfun(@eq, symbols, target_symbols), 2);
        else
            b_matrix = randi([0, 1], curr_batch_size, r*K);
            actual_f = evaluate_boolean_function_vec(b_matrix, func_type, params);

            % Convert to symbols for RS encoding
            symbols = zeros(curr_batch_size, K);
            weights_sym = 2.^((r-1):-1:0);
            for k = 1:K
                idx = (k-1)*r + 1 : k*r;
                symbols(:, k) = sum(b_matrix(:, idx) .* weights_sym, 2);
            end
            P = gf(symbols, r);
        end

        % Encode batch (P * X)
        C = P * X;
        C_ints = C.x;

        % Choose uniform indices u from {1...L} for each trial in the batch
        U = randi([1, L], curr_batch_size, 1);

        % Extract received symbols
        row_indices = (1:curr_batch_size)';
        linear_indices = sub2ind([curr_batch_size, L], row_indices, U);
        received_symbols_x = C_ints(linear_indices);

        % Check if received symbols are valid using lookup table
        lookup_indices = sub2ind([L, 2^r], U, received_symbols_x + 1);
        decoded_f = valid_lookup(lookup_indices);

        % add an always decodes 0 baseline
        decoded_f_baseline = false(curr_batch_size, 1); % always decodes 0

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