function stat = run_monte_carlo_fixed_msg_vec(fixed_symbols, valid_symbols_uint32, r, K, L, func_type, params, num_trials)
    % run_monte_carlo_fixed_msg_vec: Estimates FP rate for a single FIXED message W_fixed.
    %
    % For a fixed message W_fixed, the only randomness comes from the position index U ~ Unif({1..L}).
    % Since there are L evaluation positions in total, position evaluation can be parallelized 
    % and pre-evaluated in vectorized form across all L positions.
    %
    % Inputs:
    %   fixed_symbols        - uint32 [1 x K] vector representing fixed message W_fixed
    %   valid_symbols_uint32 - uint32 [S x K] matrix representing valid message set
    %   r, K, L, func_type, params - System parameters
    %   num_trials           - Number of Monte Carlo position samples
    %
    % Output:
    %   stat - struct with fields:
    %          fp_prob_exact: Exact FP probability R/L computed deterministically over all L positions
    %          fp_prob_mc: Empirical FP probability from Monte Carlo position sampling
    %          R: Exact number of positions resulting in false positive (0 <= R <= K-1)
    %          L: Total evaluation positions L = 2^r

    S = size(valid_symbols_uint32, 1);
    if S == 0
        stat = struct('fp_prob_exact', 0, 'fp_prob_mc', 0, 'R', 0, 'L', L);
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

    % 2. Compute transmitted symbol Y_fixed(l) = C_{W_fixed}(alpha^l) for ALL L positions in vector form
    y_fixed_all = repmat(fixed_symbols(K), 1, L);
    for k = (K-1):-1:1
        y_fixed_all = bitxor(gf_mul_vec(y_fixed_all, alpha_powers, r, prim_poly), fixed_symbols(k));
    end

    % 3. Compute valid codeword symbols for all L positions: [S x L] uint32
    C_valid_all = repmat(valid_symbols_uint32(:, K), 1, L);
    for k = (K-1):-1:1
        C_valid_all = bitxor(gf_mul_vec(C_valid_all, alpha_powers, r, prim_poly), valid_symbols_uint32(:, k));
    end

    % 4. Deterministically evaluate FP status for each of the L positions
    is_fp_at_pos = false(1, L);
    for l = 1:L
        valid_set_l = unique(C_valid_all(:, l));
        is_fp_at_pos(l) = ismember(y_fixed_all(l), valid_set_l);
    end

    % Exact number of FP positions R and exact FP probability R/L
    R = sum(is_fp_at_pos);
    fp_prob_exact = R / L;

    % 5. Position-Parallel Monte Carlo Sampling over U ~ Unif({1..L})
    % Parallelize trial batches of position indices U across workers
    batch_size = 100000;
    num_batches = ceil(num_trials / batch_size);
    total_fp_mc = 0;

    parfor b = 1:num_batches
        curr_batch_size = min(batch_size, num_trials - (b - 1) * batch_size);
        U_batch = randi([1, L], curr_batch_size, 1);
        
        % Fast lookup into pre-computed position FP status
        total_fp_mc = total_fp_mc + sum(is_fp_at_pos(U_batch));
    end

    fp_prob_mc = total_fp_mc / num_trials;

    stat = struct('fp_prob_exact', fp_prob_exact, ...
                  'fp_prob_mc', fp_prob_mc, ...
                  'R', R, ...
                  'L', L);
end
