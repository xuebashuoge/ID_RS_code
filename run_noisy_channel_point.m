function result = run_noisy_channel_point(cfg, bank, channel_type, ebno_db, result_file)
%RUN_NOISY_CHANNEL_POINT Simulate one (n, channel, Eb/N0) scenario.

    result_version = 3;

    if nargin < 5
        result_file = '';
    end
    if ~isempty(result_file) && isfile(result_file)
        loaded = load(result_file, 'result');
        saved_version = 0;
        if isfield(loaded, 'result') && isfield(loaded.result, 'version')
            saved_version = double(loaded.result.version);
        end
        if isfield(loaded, 'result') && isfield(loaded.result, 'complete') && ...
                loaded.result.complete && saved_version >= result_version
            result = loaded.result;
            fprintf('Using completed result %s\n', result_file);
            return;
        end
        fprintf(['Existing point %s predates transition decomposition; ' ...
            'rerunning it with the saved source bank.\n'], result_file);
    end

    require_communications_toolbox();
    d = derive_bfc_parameters(cfg, bank.metadata.n);
    validate_point_inputs(cfg, bank, d, channel_type);
    p1 = min(1, 2^bank.metadata.log2_p1);

    channel_index = find(strcmpi(channel_type, cfg.channel_types), 1);
    scenario_seed = mod(cfg.seed + 1009*d.n + 100003*channel_index + ...
        1009*round(1000*(ebno_db+100)), 2^31-1);
    rng(scenario_seed, 'twister');

    H = dvbs2ldpc(cfg.ldpc.rate);
    encoder_cfg = ldpcEncoderConfig(H);
    decoder_cfg = ldpcDecoderConfig(encoder_cfg, cfg.ldpc.algorithm);
    if encoder_cfg.BlockLength ~= d.ldpc_N || encoder_cfg.NumInformationBits ~= d.ldpc_K
        error('Configured LDPC dimensions do not match dvbs2ldpc(%g).', cfg.ldpc.rate);
    end

    counts.coded = empty_decision_counts();
    counts.uncoded = empty_decision_counts();
    counts.noiseless = empty_decision_counts();
    counts.erasure = empty_decision_counts();
    transition_counts = empty_transition_counts();
    channel_counts = struct( ...
        'ldpc_payload_bit_errors', 0, 'ldpc_payload_bits', 0, ...
        'ldpc_frame_errors', 0, 'ldpc_frames', 0, ...
        'ldpc_parity_failures', 0, 'ldpc_iteration_sum', 0, ...
        'coded_tuple_errors', 0, 'uncoded_tuple_errors', 0, ...
        'uncoded_bit_errors', 0, 'uncoded_bits', 0);

    per_frame.ldpc_error = false(cfg.mc.max_frames, 1);
    per_frame.parity_failure = false(cfg.mc.max_frames, 1);
    per_frame.coded_bfc_errors = zeros(cfg.mc.max_frames, 1, 'uint32');
    per_frame.uncoded_bfc_errors = zeros(cfg.mc.max_frames, 1, 'uint32');
    per_frame.coded_weighted_error = zeros(cfg.mc.max_frames, 1);
    per_frame.uncoded_weighted_error = zeros(cfg.mc.max_frames, 1);
    per_frame.noiseless_weighted_error = zeros(cfg.mc.max_frames, 1);

    frames_done = 0;
    start_time = tic;
    next_progress_seconds = cfg.mc.progress_interval_seconds;
    fprintf('Simulating n=%d, %s, Eb/N0=%g dB, G=%d tuples/frame\n', ...
        d.n, channel_type, ebno_db, d.tuples_per_frame);

    while frames_done < cfg.mc.max_frames
        frame_count = min(cfg.memory.frames_per_batch, cfg.mc.max_frames-frames_done);
        tuple_first = frames_done*d.tuples_per_frame + 1;
        tuple_last = (frames_done+frame_count)*d.tuples_per_frame;
        rows = tuple_first:tuple_last;

        u_sent = bank.u(rows);
        c_sent = bank.c(rows);
        actual_f = bank.actual_f(rows);
        noiseless_f = bank.noiseless_f(rows);
        [info_bits, payload_bits] = pack_bfc_tuples( ...
            u_sent, c_sent, d.r, d.ldpc_K, d.tuples_per_frame);

        encoded_bits = ldpcEncode(info_bits, encoder_cfg);
        coded_llr = transmit_bpsk_llr( ...
            encoded_bits, channel_type, ebno_db, d.ldpc_payload_rate);
        [decoded_info, iterations, final_checks] = ldpcDecode( ...
            coded_llr, decoder_cfg, cfg.ldpc.max_iterations, ...
            'OutputFormat', 'info', 'DecisionType', 'hard', ...
            'Termination', 'early', ...
            'MinSumScalingFactor', cfg.ldpc.min_sum_scaling, ...
            'Multithreaded', cfg.ldpc.multithreaded);
        decoded_payload = logical(decoded_info(1:d.payload_bits_per_frame, :));
        [u_coded, c_coded] = unpack_bfc_tuples(decoded_payload, d.r);
        coded_f = decode_received_bfc( ...
            u_coded, c_coded, u_sent, c_sent, noiseless_f, bank, cfg.memory);

        uncoded_llr = transmit_bpsk_llr(payload_bits, channel_type, ebno_db, 1);
        uncoded_payload = uncoded_llr < 0;
        [u_uncoded, c_uncoded] = unpack_bfc_tuples(uncoded_payload, d.r);
        uncoded_f = decode_received_bfc( ...
            u_uncoded, c_uncoded, u_sent, c_sent, noiseless_f, bank, cfg.memory);

        parity_failed = any(final_checks ~= 0, 1);
        erasure_f = coded_f;
        erasure_tuple_mask = repelem(parity_failed(:), d.tuples_per_frame);
        erasure_f(erasure_tuple_mask) = false;

        counts.coded = add_decisions(counts.coded, actual_f, coded_f);
        counts.uncoded = add_decisions(counts.uncoded, actual_f, uncoded_f);
        counts.noiseless = add_decisions(counts.noiseless, actual_f, noiseless_f);
        counts.erasure = add_decisions(counts.erasure, actual_f, erasure_f);
        transition_counts = add_transitions(transition_counts, ...
            actual_f, noiseless_f, coded_f);

        payload_error_matrix = decoded_payload ~= payload_bits;
        frame_error = any(payload_error_matrix, 1);
        channel_counts.ldpc_payload_bit_errors = channel_counts.ldpc_payload_bit_errors + sum(payload_error_matrix(:));
        channel_counts.ldpc_payload_bits = channel_counts.ldpc_payload_bits + numel(payload_error_matrix);
        channel_counts.ldpc_frame_errors = channel_counts.ldpc_frame_errors + sum(frame_error);
        channel_counts.ldpc_frames = channel_counts.ldpc_frames + frame_count;
        channel_counts.ldpc_parity_failures = channel_counts.ldpc_parity_failures + sum(parity_failed);
        channel_counts.ldpc_iteration_sum = channel_counts.ldpc_iteration_sum + sum(iterations);
        channel_counts.coded_tuple_errors = channel_counts.coded_tuple_errors + ...
            sum((u_coded ~= u_sent) | (c_coded ~= c_sent));
        channel_counts.uncoded_tuple_errors = channel_counts.uncoded_tuple_errors + ...
            sum((u_uncoded ~= u_sent) | (c_uncoded ~= c_sent));
        channel_counts.uncoded_bit_errors = channel_counts.uncoded_bit_errors + ...
            sum(xor(uncoded_payload, payload_bits), 'all');
        channel_counts.uncoded_bits = channel_counts.uncoded_bits + numel(payload_bits);

        frame_rows = frames_done + (1:frame_count);
        per_frame.ldpc_error(frame_rows) = frame_error(:);
        per_frame.parity_failure(frame_rows) = parity_failed(:);
        per_frame.coded_bfc_errors(frame_rows) = uint32(sum(reshape(actual_f ~= coded_f, d.tuples_per_frame, []), 1));
        per_frame.uncoded_bfc_errors(frame_rows) = uint32(sum(reshape(actual_f ~= uncoded_f, d.tuples_per_frame, []), 1));
        per_frame.coded_weighted_error(frame_rows) = frame_weighted_errors( ...
            actual_f, coded_f, d.tuples_per_frame, p1);
        per_frame.uncoded_weighted_error(frame_rows) = frame_weighted_errors( ...
            actual_f, uncoded_f, d.tuples_per_frame, p1);
        per_frame.noiseless_weighted_error(frame_rows) = frame_weighted_errors( ...
            actual_f, noiseless_f, d.tuples_per_frame, p1);

        frames_done = frames_done + frame_count;
        elapsed_seconds = toc(start_time);
        if elapsed_seconds >= next_progress_seconds
            fprintf(['  progress: %d frames, FP=%d/%d negatives, ' ...
                'FN=%d/%d positives, %.1f hours\n'], ...
                frames_done, counts.coded.false_positive, ...
                counts.coded.actual_zero, counts.coded.false_negative, ...
                counts.coded.actual_one, elapsed_seconds/3600);
            next_progress_seconds = next_progress_seconds + ...
                cfg.mc.progress_interval_seconds;
        end
        [classes_resolved, all_targets_reached] = ...
            class_stopping_status(counts.coded, cfg.mc);
        if frames_done >= cfg.mc.min_frames && classes_resolved
            if all_targets_reached
                stopping_reason = 'target_fp_fn_counts';
            else
                stopping_reason = 'class_trial_cap';
            end
            break;
        end
        if elapsed_seconds >= cfg.mc.max_runtime_seconds
            stopping_reason = 'max_runtime_seconds';
            break;
        end
        stopping_reason = 'max_frames';
    end

    result.complete = true;
    result.version = result_version;
    result.config = cfg;
    result.scenario = struct('n', d.n, 'channel', lower(channel_type), ...
        'ebno_db', ebno_db, 'E2', cfg.bfc.E2, ...
        'ldpc_rate', cfg.ldpc.rate, 'seed', scenario_seed);
    result.derived = d;
    result.bank_metadata = bank.metadata;
    result.frames = frames_done;
    result.tuples = frames_done*d.tuples_per_frame;
    result.stopping_reason = stopping_reason;
    result.runtime_seconds = toc(start_time);
    result.counts = counts;
    result.channel_counts = channel_counts;
    result.transition_counts = transition_counts;
    result.metrics.coded = finalize_decisions(counts.coded, p1);
    result.metrics.uncoded = finalize_decisions(counts.uncoded, p1);
    result.metrics.noiseless = finalize_decisions(counts.noiseless, p1);
    result.metrics.erasure = finalize_decisions(counts.erasure, p1);
    result.metrics.coded.cluster_ci95 = cluster_mean_ci( ...
        per_frame.coded_weighted_error(1:frames_done));
    result.metrics.uncoded.cluster_ci95 = cluster_mean_ci( ...
        per_frame.uncoded_weighted_error(1:frames_done));
    result.metrics.noiseless.cluster_ci95 = cluster_mean_ci( ...
        per_frame.noiseless_weighted_error(1:frames_done));
    result.metrics.ldpc_payload_ber = safe_ratio( ...
        channel_counts.ldpc_payload_bit_errors, channel_counts.ldpc_payload_bits);
    result.metrics.ldpc_fer = safe_ratio( ...
        channel_counts.ldpc_frame_errors, channel_counts.ldpc_frames);
    result.metrics.ldpc_parity_failure_rate = safe_ratio( ...
        channel_counts.ldpc_parity_failures, channel_counts.ldpc_frames);
    result.metrics.mean_ldpc_iterations = safe_ratio( ...
        channel_counts.ldpc_iteration_sum, channel_counts.ldpc_frames);
    result.metrics.coded_tuple_error_rate = safe_ratio( ...
        channel_counts.coded_tuple_errors, result.tuples);
    result.metrics.uncoded_tuple_error_rate = safe_ratio( ...
        channel_counts.uncoded_tuple_errors, result.tuples);
    result.metrics.uncoded_ber = safe_ratio( ...
        channel_counts.uncoded_bit_errors, channel_counts.uncoded_bits);
    result.metrics.decomposition = finalize_transitions(transition_counts);
    reconstructed_error = result.metrics.decomposition.intrinsic_error + ...
        result.metrics.decomposition.channel_created_error - ...
        result.metrics.decomposition.channel_corrected_intrinsic_error;
    if abs(reconstructed_error-result.metrics.coded.balanced_error) > 1e-12
        error('The BFC error decomposition identity failed.');
    end
    [classes_resolved, all_targets_reached, stopping_status] = ...
        class_stopping_status(counts.coded, cfg.mc);
    result.stopping = stopping_status;
    result.stopping.classes_resolved = classes_resolved;
    result.stopping.all_targets_reached = all_targets_reached;
    result.stopping.frames = frames_done;
    result.stopping.runtime_seconds = result.runtime_seconds;
    result.per_frame.ldpc_error = per_frame.ldpc_error(1:frames_done);
    result.per_frame.parity_failure = per_frame.parity_failure(1:frames_done);
    result.per_frame.coded_bfc_errors = per_frame.coded_bfc_errors(1:frames_done);
    result.per_frame.uncoded_bfc_errors = per_frame.uncoded_bfc_errors(1:frames_done);
    result.per_frame.coded_weighted_error = per_frame.coded_weighted_error(1:frames_done);
    result.per_frame.uncoded_weighted_error = per_frame.uncoded_weighted_error(1:frames_done);
    result.per_frame.noiseless_weighted_error = per_frame.noiseless_weighted_error(1:frames_done);

    fprintf(['  coded BFC error %.4g, FPR %.4g, FNR %.4g, ' ...
        'LDPC FER %.4g (%d frames, %.1fs, %s)\n'], ...
        result.metrics.coded.balanced_error, result.metrics.coded.fpr, ...
        result.metrics.coded.fnr, result.metrics.ldpc_fer, frames_done, ...
        result.runtime_seconds, stopping_reason);

    if ~isempty(result_file)
        parent_dir = fileparts(result_file);
        if ~exist(parent_dir, 'dir')
            mkdir(parent_dir);
        end
        temporary_file = [tempname(parent_dir) '.mat'];
        save(temporary_file, 'result', '-v7.3');
        movefile(temporary_file, result_file, 'f');
    end
end

function require_communications_toolbox()
    required = {'dvbs2ldpc', 'ldpcEncoderConfig', 'ldpcDecoderConfig', ...
        'ldpcEncode', 'ldpcDecode'};
    missing = required(cellfun(@(name) exist(name, 'file') == 0, required));
    if ~isempty(missing)
        error('Communications Toolbox APIs are unavailable: %s', strjoin(missing, ', '));
    end
    if ~license('test', 'Communication_Toolbox')
        error('A Communications Toolbox license is required.');
    end
end

function validate_point_inputs(cfg, bank, d, channel_type)
    if ~bank.metadata.complete || bank.metadata.n ~= d.n
        error('Source bank is incomplete or belongs to another n.');
    end
    if ~isfield(bank.metadata, 'rs_evaluation_order') || ...
            ~strcmp(bank.metadata.rs_evaluation_order, d.rs_evaluation_order)
        error('Source bank uses an incompatible RS evaluation-point mapping.');
    end
    if numel(bank.u) < cfg.mc.max_frames*d.tuples_per_frame
        error('Source bank is too short for the requested maximum frame count.');
    end
    if ~any(strcmpi(channel_type, {'awgn', 'rayleigh'}))
        error('Channel must be "awgn" or "rayleigh".');
    end
    if strcmpi(channel_type, 'rayleigh') && ~strcmpi(cfg.rayleigh.csi, 'perfect')
        error('The initial Rayleigh implementation supports perfect CSI only.');
    end
    required_mc_fields = {'min_frames', 'max_frames', ...
        'target_false_positives', 'target_false_negatives', ...
        'max_trials_per_class', 'max_runtime_seconds', ...
        'progress_interval_seconds'};
    missing_mc_fields = required_mc_fields(~isfield(cfg.mc, required_mc_fields));
    if ~isempty(missing_mc_fields)
        error('Missing Monte Carlo configuration fields: %s.', ...
            strjoin(missing_mc_fields, ', '));
    end
    validateattributes(cfg.mc.target_false_positives, {'numeric'}, ...
        {'scalar', 'integer', 'nonnegative'});
    validateattributes(cfg.mc.target_false_negatives, {'numeric'}, ...
        {'scalar', 'integer', 'nonnegative'});
    validateattributes(cfg.mc.max_trials_per_class, {'numeric'}, ...
        {'scalar', 'integer', 'positive'});
    validateattributes(cfg.mc.max_runtime_seconds, {'numeric'}, ...
        {'scalar', 'real', 'finite', 'positive'});
    validateattributes(cfg.mc.progress_interval_seconds, {'numeric'}, ...
        {'scalar', 'real', 'finite', 'positive'});
end

function counts = empty_decision_counts()
    counts = struct('actual_zero', 0, 'actual_one', 0, ...
        'false_positive', 0, 'false_negative', 0, 'total', 0);
end

function counts = empty_transition_counts()
    counts = struct('total', 0, 'intrinsic_error', 0, ...
        'channel_created_error', 0, ...
        'channel_corrected_intrinsic_error', 0, ...
        'channel_decision_changes', 0);
end

function counts = add_decisions(counts, actual, decoded)
    actual = logical(actual(:));
    decoded = logical(decoded(:));
    counts.actual_zero = counts.actual_zero + sum(~actual);
    counts.actual_one = counts.actual_one + sum(actual);
    counts.false_positive = counts.false_positive + sum(~actual & decoded);
    counts.false_negative = counts.false_negative + sum(actual & ~decoded);
    counts.total = counts.total + numel(actual);
end

function counts = add_transitions(counts, actual, noiseless, coded)
    actual = logical(actual(:));
    noiseless = logical(noiseless(:));
    coded = logical(coded(:));
    intrinsic = noiseless ~= actual;
    coded_error = coded ~= actual;
    counts.total = counts.total + numel(actual);
    counts.intrinsic_error = counts.intrinsic_error + sum(intrinsic);
    counts.channel_created_error = counts.channel_created_error + ...
        sum(~intrinsic & coded_error);
    counts.channel_corrected_intrinsic_error = ...
        counts.channel_corrected_intrinsic_error + ...
        sum(intrinsic & ~coded_error);
    counts.channel_decision_changes = counts.channel_decision_changes + ...
        sum(coded ~= noiseless);
end

function metrics = finalize_decisions(counts, p1)
    metrics.fpr = safe_ratio(counts.false_positive, counts.actual_zero);
    metrics.fnr = safe_ratio(counts.false_negative, counts.actual_one);
    metrics.balanced_error = safe_ratio( ...
        counts.false_positive+counts.false_negative, counts.total);
    metrics.p1 = p1;
    metrics.false_positive_contribution = (1-p1)*metrics.fpr;
    metrics.false_negative_contribution = p1*metrics.fnr;
    metrics.weighted_error = metrics.false_positive_contribution + ...
        metrics.false_negative_contribution;
end

function metrics = finalize_transitions(counts)
    metrics.intrinsic_error = safe_ratio( ...
        counts.intrinsic_error, counts.total);
    metrics.channel_created_error = safe_ratio( ...
        counts.channel_created_error, counts.total);
    metrics.channel_corrected_intrinsic_error = safe_ratio( ...
        counts.channel_corrected_intrinsic_error, counts.total);
    metrics.channel_decision_change_rate = safe_ratio( ...
        counts.channel_decision_changes, counts.total);
end

function [resolved, all_targets, status] = class_stopping_status(counts, mc)
    fp_target = counts.false_positive >= mc.target_false_positives;
    fn_target = counts.false_negative >= mc.target_false_negatives;
    fp_capped = counts.actual_zero >= mc.max_trials_per_class;
    fn_capped = counts.actual_one >= mc.max_trials_per_class;
    resolved = (fp_target || fp_capped) && (fn_target || fn_capped);
    all_targets = fp_target && fn_target;
    status = struct( ...
        'target_false_positives', mc.target_false_positives, ...
        'target_false_negatives', mc.target_false_negatives, ...
        'max_trials_per_class', mc.max_trials_per_class, ...
        'false_positive_target_reached', fp_target, ...
        'false_negative_target_reached', fn_target, ...
        'false_positive_trial_cap_reached', fp_capped, ...
        'false_negative_trial_cap_reached', fn_capped);
end

function value = safe_ratio(numerator, denominator)
    if denominator == 0
        value = NaN;
    else
        value = double(numerator) / double(denominator);
    end
end

function values = frame_weighted_errors(actual, decoded, tuples_per_frame, p1)
    actual = reshape(logical(actual), tuples_per_frame, []);
    decoded = reshape(logical(decoded), tuples_per_frame, []);
    zero_count = sum(~actual, 1);
    one_count = sum(actual, 1);
    fpr = sum(~actual & decoded, 1) ./ zero_count;
    fnr = sum(actual & ~decoded, 1) ./ one_count;
    values = ((1-p1).*fpr + p1.*fnr).';
end

function ci = cluster_mean_ci(values)
    values = double(values(:));
    estimate = mean(values);
    if numel(values) < 2
        half_width = NaN;
    else
        half_width = 1.96 * std(values, 0) / sqrt(numel(values));
    end
    ci = [max(0, estimate-half_width), min(1, estimate+half_width)];
end
