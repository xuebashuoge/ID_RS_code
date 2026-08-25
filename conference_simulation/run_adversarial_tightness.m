function run_adversarial_tightness()
%RUN_ADVERSARIAL_TIGHTNESS Verify a support attaining S(K-1)/L.
% Uses the same 0-based task/n array mapping as the finite-length runner.
% Expensive cases can be guarded with BFC_ADVERSARIAL_MAX_K and
% BFC_ADVERSARIAL_MAX_PROXY, then explicitly enabled on the server.

    root_dir = fileparts(fileparts(mfilename('fullpath')));
    addpath(root_dir, fullfile(root_dir, 'conference_simulation'));
    cd(root_dir);
    cfg = conference_config();

    array_index = floor(get_env_number('BFC_ARRAY_INDEX', ...
        get_env_number('SLURM_ARRAY_TASK_ID', 0)));
    num_n = numel(cfg.n_values);
    task_index = floor(array_index / num_n) + 1;
    n_index = mod(array_index, num_n) + 1;
    if task_index < 1 || task_index > numel(cfg.tasks)
        error('Array index %d is outside the configured task/n grid.', array_index);
    end

    func_type = cfg.tasks{task_index};
    n = cfg.n_values(n_index);
    r = n / 2;
    L = 2^r;
    K = K_calculator(n, cfg.E_FP, cfg.params, func_type);
    m = r * K;
    S = conference_support_size(m, func_type, cfg.params);
    theorem_bound = min(1, S * (K - 1) / L);
    max_K = get_env_number('BFC_ADVERSARIAL_MAX_K', 5000);
    max_proxy = get_env_number('BFC_ADVERSARIAL_MAX_PROXY', 1e11);
    operation_proxy = double(S + 1) * double(K) * double(L);

    output_dir = fullfile(cfg.raw_dir, 'adversarial');
    if ~isfolder(output_dir)
        mkdir(output_dir);
    end
    result_path = fullfile(output_dir, sprintf( ...
        'adversarial_%s_n%03d.mat', func_type, n));
    if isfile(result_path)
        fprintf('Adversarial result already exists: %s\n', result_path);
        return;
    end

    metadata = struct('func_type', func_type, 'n', n, 'r', r, 'L', L, ...
        'K', K, 'm', m, 'S', S, 'theorem_bound', theorem_bound, ...
        'operation_proxy', operation_proxy, 'verified', false, ...
        'status', 'not_started');

    if S * (K - 1) > L
        metadata.status = 'bound_exceeds_constructible_range';
        save(result_path, 'metadata');
        return;
    end
    if K > max_K || operation_proxy > max_proxy
        metadata.status = 'skipped_by_cost_guard';
        save(result_path, 'metadata');
        fprintf(['Skipped %s n=%d: K=%d, proxy=%.3e. Override ', ...
            'BFC_ADVERSARIAL_MAX_K/MAX_PROXY to run it.\n'], ...
            func_type, n, K, operation_proxy);
        return;
    end

    requested_workers = floor(get_env_number('BFC_NUM_WORKERS', ...
        get_env_number('SLURM_CPUS_PER_TASK', feature('numcores'))));
    start_conference_pool(requested_workers);
    [negative_symbols, support_symbols, collision_positions] = ...
        build_adversarial_support(r, K, L, S);
    checkpoint_path = fullfile(output_dir, sprintf( ...
        'adversarial_%s_n%03d_checkpoint.mat', func_type, n));
    signature = double([r, K, L, S, -1]);
    stat = exact_negative_fpr_distribution( ...
        support_symbols, negative_symbols, r, L, ...
        'ChunkSize', floor(get_env_number( ...
            'BFC_CHUNK_SIZE', cfg.position_chunk_size)), ...
        'CheckpointEveryChunks', cfg.checkpoint_every_chunks, ...
        'CheckpointPath', checkpoint_path, ...
        'Signature', signature);

    expected_R = S * (K - 1);
    observed_R = stat.R_counts(1);
    if observed_R ~= expected_R
        error('Tightness check failed: observed R=%d, expected R=%d.', ...
            observed_R, expected_R);
    end
    metadata.verified = true;
    metadata.status = 'verified_exactly';
    metadata.observed_R = observed_R;
    metadata.observed_fpr = stat.fpr_exact(1);
    metadata.completed_at = char(datetime('now', 'TimeZone', 'local'));
    save(result_path, 'metadata', 'stat', 'collision_positions', '-v7.3');
    fprintf('Verified exact theorem-bound equality for %s at n=%d.\n', ...
        func_type, n);
end
