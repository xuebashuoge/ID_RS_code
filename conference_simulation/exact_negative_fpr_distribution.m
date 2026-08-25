function stat = exact_negative_fpr_distribution( ...
    valid_symbols, negative_symbols, r, L, options)
%EXACT_NEGATIVE_FPR_DISTRIBUTION Compute exact R_i/L for sampled negatives.
%
% The position loop is chunked. Positive-support codeword symbols are
% evaluated once per chunk and shared by all sampled negative messages.
% A checkpoint contains only accumulated counts; deterministic sampling in
% the caller reconstructs the messages when a job is resumed.

    arguments
        valid_symbols (:,:) uint32
        negative_symbols (:,:) uint32
        r (1,1) double {mustBeInteger, mustBePositive}
        L (1,1) double {mustBeInteger, mustBePositive}
        options.ChunkSize (1,1) double {mustBeInteger, mustBePositive} = 512
        options.CheckpointEveryChunks (1,1) double {mustBeInteger, mustBePositive} = 20
        options.CheckpointPath (1,:) char = ''
        options.Signature (1,:) double = []
    end

    [S, K] = size(valid_symbols);
    [num_messages, K_negative] = size(negative_symbols);
    if K ~= K_negative
        error('Positive and negative symbol matrices must have the same K.');
    end
    if S == 0
        error('The positive support must be nonempty.');
    end

    prim_poly = get_primpoly(r);
    eval_points = rs_evaluation_points(r, L, prim_poly);
    R_counts = zeros(num_messages, 1);
    region_unique_sum = 0;
    next_position = 1;
    chunks_completed = 0;

    if ~isempty(options.CheckpointPath) && isfile(options.CheckpointPath)
        saved = load(options.CheckpointPath, 'checkpoint');
        checkpoint = saved.checkpoint;
        if ~isequal(checkpoint.signature, options.Signature)
            error('Checkpoint signature does not match the requested run: %s', ...
                options.CheckpointPath);
        end
        if numel(checkpoint.R_counts) ~= num_messages
            error('Checkpoint message count does not match the requested run.');
        end
        R_counts = checkpoint.R_counts;
        region_unique_sum = checkpoint.region_unique_sum;
        next_position = checkpoint.next_position;
        chunks_completed = checkpoint.chunks_completed;
        fprintf('Resuming exact evaluation at position %d of %d.\n', ...
            next_position, L);
    end

    total_chunks = ceil(L / options.ChunkSize);
    run_clock = tic;
    for chunk_start = next_position:options.ChunkSize:L
        chunk_end = min(L, chunk_start + options.ChunkSize - 1);
        positions = chunk_start:chunk_end;
        x_chunk = eval_points(positions);

        valid_values = evaluate_symbol_polynomials( ...
            valid_symbols, x_chunk, r, prim_poly);
        negative_values = evaluate_symbol_polynomials( ...
            negative_symbols, x_chunk, r, prim_poly);

        num_positions = numel(positions);
        hit_chunk = false(num_messages, num_positions);
        unique_counts = zeros(1, num_positions);
        parfor local_position = 1:num_positions
            decoding_values = unique(valid_values(:, local_position));
            unique_counts(local_position) = numel(decoding_values);
            hit_chunk(:, local_position) = ismember( ...
                negative_values(:, local_position), decoding_values);
        end

        R_counts = R_counts + sum(hit_chunk, 2);
        region_unique_sum = region_unique_sum + sum(unique_counts);
        chunks_completed = chunks_completed + 1;
        next_position = chunk_end + 1;

        should_checkpoint = mod(chunks_completed, ...
            options.CheckpointEveryChunks) == 0 || next_position > L;
        if should_checkpoint && ~isempty(options.CheckpointPath)
            checkpoint = struct( ...
                'signature', options.Signature, ...
                'R_counts', R_counts, ...
                'region_unique_sum', region_unique_sum, ...
                'next_position', next_position, ...
                'chunks_completed', chunks_completed, ...
                'updated_at', char(datetime('now', 'TimeZone', 'local')));
            checkpoint_dir = fileparts(options.CheckpointPath);
            if ~isempty(checkpoint_dir) && ~isfolder(checkpoint_dir)
                mkdir(checkpoint_dir);
            end
            save(options.CheckpointPath, 'checkpoint', '-v7.3');
        end

        fprintf(['Chunk %d/%d complete (positions %d:%d, ', ...
            'elapsed %.1f min).\n'], chunks_completed, total_chunks, ...
            chunk_start, chunk_end, toc(run_clock) / 60);
    end

    fpr_exact = R_counts / L;
    quantiles = empirical_quantile(fpr_exact, [0.05, 0.50, 0.95]);

    m = r * K;
    log_positive_mass = log2(double(S)) - m;
    if log_positive_mass < -1074
        positive_mass = 0;
    else
        positive_mass = 2^log_positive_mass;
    end
    average_joint_fp = region_unique_sum / (L * 2^r) - positive_mass;
    average_joint_fp = max(0, average_joint_fp);
    average_conditional_fp = average_joint_fp / (1 - positive_mass);

    stat = struct( ...
        'R_counts', R_counts, ...
        'fpr_exact', fpr_exact, ...
        'q05', quantiles(1), ...
        'median', quantiles(2), ...
        'q95', quantiles(3), ...
        'sample_max', max(fpr_exact), ...
        'sample_mean', mean(fpr_exact), ...
        'region_unique_sum', region_unique_sum, ...
        'positive_message_mass', positive_mass, ...
        'average_joint_fp', average_joint_fp, ...
        'average_conditional_fp', average_conditional_fp);
end
