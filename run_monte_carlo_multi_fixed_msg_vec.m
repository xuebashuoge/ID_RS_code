function stat = run_monte_carlo_multi_fixed_msg_vec(valid_symbols_uint32, r, K, L, func_type, params, num_fixed_msgs, num_trials_per_msg)
    % run_monte_carlo_multi_fixed_msg_vec: Evaluates multiple fixed messages in parallel
    % to analyze the distribution of FP rates across different choices of fixed W_fixed.
    %
    % Inputs:
    %   valid_symbols_uint32 - uint32 [S x K] matrix representing valid message set
    %   r, K, L, func_type, params - System parameters
    %   num_fixed_msgs       - Number of fixed messages to sample and evaluate
    %   num_trials_per_msg   - Number of Monte Carlo position trials per message
    %
    % Output:
    %   stat - struct containing summary statistics and array of FP rates across all fixed messages

    field_size = 2^r;

    % Generate target symbols for ID task
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

    % Generate num_fixed_msgs non-matching fixed messages
    fixed_msgs_symbols = zeros(num_fixed_msgs, K, 'uint32');
    m_count = 0;
    while m_count < num_fixed_msgs
        cand = uint32(randi([0, field_size - 1], 1, K));
        if strcmpi(func_type, 'id') && all(cand == target_symbols)
            continue; % skip target message
        end
        m_count = m_count + 1;
        fixed_msgs_symbols(m_count, :) = cand;
    end

    fp_probs_exact = zeros(num_fixed_msgs, 1);
    fp_probs_mc = zeros(num_fixed_msgs, 1);
    R_vals = zeros(num_fixed_msgs, 1);

    % Parallelize across the fixed messages
    parfor m_idx = 1:num_fixed_msgs
        fixed_symbols = fixed_msgs_symbols(m_idx, :);
        sub_stat = run_monte_carlo_fixed_msg_vec(fixed_symbols, valid_symbols_uint32, r, K, L, func_type, params, num_trials_per_msg);
        
        fp_probs_exact(m_idx) = sub_stat.fp_prob_exact;
        fp_probs_mc(m_idx) = sub_stat.fp_prob_mc;
        R_vals(m_idx) = sub_stat.R;
    end

    stat = struct('fp_prob_mean', mean(fp_probs_exact), ...
                  'fp_prob_max', max(fp_probs_exact), ...
                  'fp_prob_min', min(fp_probs_exact), ...
                  'fp_probs_exact', fp_probs_exact, ...
                  'fp_probs_mc', fp_probs_mc, ...
                  'R_vals', R_vals, ...
                  'L', L);
end
