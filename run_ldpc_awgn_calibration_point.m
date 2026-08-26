function result = run_ldpc_awgn_calibration_point( ...
        cfg, rate, algorithm, ebno_db, result_file)
%RUN_LDPC_AWGN_CALIBRATION_POINT Fixed-frame DVB-S2 LDPC AWGN check.

    if nargin < 5
        result_file = '';
    end
    if ~isempty(result_file) && isfile(result_file)
        saved = load(result_file, 'result');
        if isfield(saved, 'result') && saved.result.complete && ...
                saved.result.version >= cfg.version
            result = saved.result;
            fprintf('Using completed result %s\n', result_file);
            return;
        end
    end

    [N, K, rate] = dvbs2_ldpc_dimensions(rate);
    H = dvbs2ldpc(rate);
    encoder_cfg = ldpcEncoderConfig(H);
    decoder_cfg = ldpcDecoderConfig(encoder_cfg, algorithm);
    algorithm_index = find(strcmp(cfg.algorithms, algorithm), 1);
    rate_index = find(abs(cfg.rates-rate) < 1e-12, 1);
    seed = cfg.seed + 1009*rate_index + 100003*algorithm_index + ...
        round(1000*(ebno_db+20));
    rng(seed, 'twister');

    bit_errors = 0;
    frame_errors = 0;
    parity_failures = 0;
    iteration_sum = 0;
    frames_done = 0;
    start_time = tic;
    while frames_done < cfg.frames
        batch_frames = min(cfg.frames_per_batch, cfg.frames-frames_done);
        information = rand(K, batch_frames, 'single') > 0.5;
        encoded = ldpcEncode(information, encoder_cfg);
        llr = transmit_bpsk_llr(encoded, 'awgn', ebno_db, rate);
        decoder_arguments = { ...
            'OutputFormat', 'info', 'DecisionType', 'hard', ...
            'Termination', 'early', ...
            'Multithreaded', cfg.multithreaded};
        if strcmp(algorithm, 'norm-min-sum')
            decoder_arguments = [decoder_arguments, ...
                {'MinSumScalingFactor', cfg.min_sum_scaling}]; %#ok<AGROW>
        end
        [decoded, iterations, final_checks] = ldpcDecode( ...
            llr, decoder_cfg, cfg.max_iterations, decoder_arguments{:});
        errors = logical(decoded) ~= logical(information);
        bit_errors = bit_errors + sum(errors, 'all');
        frame_errors = frame_errors + sum(any(errors, 1));
        parity_failures = parity_failures + sum(any(final_checks ~= 0, 1));
        iteration_sum = iteration_sum + sum(iterations);
        frames_done = frames_done + batch_frames;
    end

    result.version = cfg.version;
    result.complete = true;
    result.rate = rate;
    result.algorithm = algorithm;
    result.ebno_db = ebno_db;
    result.esno_db = ebno_db + 10*log10(rate);
    result.block_length = N;
    result.information_length = K;
    result.frames = frames_done;
    result.bit_trials = frames_done*K;
    result.bit_errors = bit_errors;
    result.frame_errors = frame_errors;
    result.parity_failures = parity_failures;
    result.ber = double(bit_errors)/double(result.bit_trials);
    result.fer = double(frame_errors)/double(frames_done);
    result.parity_failure_rate = double(parity_failures)/double(frames_done);
    result.mean_iterations = double(iteration_sum)/double(frames_done);
    gamma_b = 10^(ebno_db/10);
    result.uncoded_bpsk_ber = 0.5*erfc(sqrt(gamma_b));
    result.seed = seed;
    result.runtime_seconds = toc(start_time);

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
