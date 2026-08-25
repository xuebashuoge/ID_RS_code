function run_conference_finite_length()
%RUN_CONFERENCE_FINITE_LENGTH Run one task/n cell of the exact distribution.
% Environment overrides:
%   BFC_ARRAY_INDEX, BFC_FUNC_TYPE, BFC_N, BFC_NUM_MESSAGES,
%   BFC_CHUNK_SIZE, BFC_CHECKPOINT_EVERY, BFC_SEED, BFC_SHARD_INDEX,
%   BFC_NUM_WORKERS.

    root_dir = fileparts(fileparts(mfilename('fullpath')));
    addpath(root_dir, fullfile(root_dir, 'conference_simulation'));
    cd(root_dir);
    cfg = conference_config();

    array_index = get_env_number('BFC_ARRAY_INDEX', ...
        get_env_number('SLURM_ARRAY_TASK_ID', 0));
    array_index = floor(array_index);
    num_n = numel(cfg.n_values);
    max_index = numel(cfg.tasks) * num_n - 1;
    if array_index < 0 || array_index > max_index
        error('Array index must be between 0 and %d.', max_index);
    end

    task_index = floor(array_index / num_n) + 1;
    n_index = mod(array_index, num_n) + 1;
    func_type = cfg.tasks{task_index};
    n = cfg.n_values(n_index);

    task_override = strtrim(getenv('BFC_FUNC_TYPE'));
    if ~isempty(task_override)
        func_type = task_override;
    end
    n = get_env_number('BFC_N', n);
    if mod(n, 2) ~= 0
        error('n must be even because the conference configuration uses r=n/2.');
    end

    num_messages = floor(get_env_number( ...
        'BFC_NUM_MESSAGES', cfg.num_negative_messages));
    chunk_size = floor(get_env_number( ...
        'BFC_CHUNK_SIZE', cfg.position_chunk_size));
    checkpoint_every = floor(get_env_number( ...
        'BFC_CHECKPOINT_EVERY', cfg.checkpoint_every_chunks));
    shard_index = floor(get_env_number('BFC_SHARD_INDEX', 0));

    seed_default = cfg.seed_base + 100000 * task_index + 100 * n + shard_index;
    seed = floor(get_env_number('BFC_SEED', seed_default));

    r = n / 2;
    L = 2^r;
    K = K_calculator(n, cfg.E_FP, cfg.params, func_type);
    if K < 1
        error('K_calculator returned K=%d for %s at n=%d.', K, func_type, n);
    end
    m = r * K;
    params = conference_task_params(func_type, r, K, cfg);
    [S, valid_symbols] = build_conference_support(r, K, func_type, params);

    raw_dir = fullfile(cfg.raw_dir, 'finite_length');
    if ~isfolder(raw_dir)
        mkdir(raw_dir);
    end
    run_tag = sprintf('%s_n%03d_M%06d_seed%010d_shard%03d', ...
        func_type, n, num_messages, seed, shard_index);
    result_path = fullfile(raw_dir, [run_tag, '.mat']);
    checkpoint_path = fullfile(raw_dir, [run_tag, '_checkpoint.mat']);
    if isfile(result_path)
        fprintf('Completed result already exists; leaving it unchanged: %s\n', ...
            result_path);
        return;
    end

    rng(seed, 'twister');
    rng_state_before_sampling = rng;
    negative_symbols = sample_uniform_negative_messages( ...
        num_messages, r, K, func_type, params);

    requested_workers = floor(get_env_number('BFC_NUM_WORKERS', ...
        get_env_number('SLURM_CPUS_PER_TASK', feature('numcores'))));
    start_conference_pool(requested_workers);

    operation_proxy = double(S + num_messages) * double(K) * double(L);
    fprintf(['Starting %s: n=%d, r=%d, L=%d, K=%d, m=%d, S=%d, ', ...
        'negative messages=%d, operation proxy=%.3e.\n'], ...
        func_type, n, r, L, K, m, S, num_messages, operation_proxy);

    signature = double([r, K, L, S, num_messages, seed, shard_index]);
    wall_clock = tic;
    stat = exact_negative_fpr_distribution( ...
        valid_symbols, negative_symbols, r, L, ...
        'ChunkSize', chunk_size, ...
        'CheckpointEveryChunks', checkpoint_every, ...
        'CheckpointPath', checkpoint_path, ...
        'Signature', signature);
    elapsed_seconds = toc(wall_clock);

    theorem_bound = min(1, S * (K - 1) / L);
    rate = log2(m) / n;
    [git_status, git_commit] = system('git rev-parse HEAD');
    if git_status ~= 0
        git_commit = 'unavailable';
    end
    metadata = struct( ...
        'schema_version', 1, ...
        'func_type', func_type, ...
        'E_FP_design', cfg.E_FP, ...
        'n', n, 'r', r, 'L', L, 'K', K, 'm', m, 'S', S, ...
        'rate', rate, ...
        'theorem_bound', theorem_bound, ...
        'num_negative_messages', num_messages, ...
        'seed', seed, ...
        'shard_index', shard_index, ...
        'chunk_size', chunk_size, ...
        'elapsed_seconds', elapsed_seconds, ...
        'git_commit', strtrim(git_commit), ...
        'matlab_version', version, ...
        'completed_at', char(datetime('now', 'TimeZone', 'local')));

    save(result_path, 'metadata', 'params', 'stat', ...
        'rng_state_before_sampling', '-v7.3');
    fprintf('Saved completed result: %s\n', result_path);
end
