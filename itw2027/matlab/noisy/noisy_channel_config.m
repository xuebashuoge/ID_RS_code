function cfg = noisy_channel_config(profile)
%NOISY_CHANNEL_CONFIG Configuration for the concatenated BFC/LDPC simulation.
%
%   CFG = NOISY_CHANNEL_CONFIG(PROFILE) returns one of three safe profiles:
%   "local_smoke", "server_pilot", or "server_full".

    if nargin < 1
        profile = 'local_smoke';
    end

    cfg.profile = char(profile);
    cfg.seed = 1729;

    cfg.bfc.E2 = 0.1;
    cfg.bfc.func_type = 'exact-threshold';
    cfg.bfc.params = struct('beta', 2, 't', 3, 'S_k', [1 2], 'rank', 20);
    cfg.bfc.rs_length_mode = 'extended';

    [cfg.ldpc.block_length, cfg.ldpc.information_length, ...
        cfg.ldpc.rate] = dvbs2_ldpc_dimensions(1/2);
    cfg.ldpc.algorithm = 'norm-min-sum';
    cfg.ldpc.max_iterations = 50;
    cfg.ldpc.min_sum_scaling = 0.75;
    cfg.ldpc.multithreaded = true;

    cfg.channel_types = {'awgn', 'rayleigh'};
    cfg.rayleigh.csi = 'perfect';
    cfg.rayleigh.fading_granularity = 'symbol';

    cfg.memory.frames_per_batch = 2;
    cfg.memory.sample_message_batch = 10000;
    cfg.memory.region_working_mb = 256;
    cfg.memory.max_valid_set_mb = 1024;
    cfg.memory.max_valid_messages = 5e6;

    cfg.mc.min_frames = 10;
    cfg.mc.target_false_positives = 20;
    cfg.mc.target_false_negatives = 20;
    cfg.mc.max_trials_per_class = 1e5;
    cfg.mc.max_frames = 20;
    cfg.mc.max_runtime_seconds = 30*60;
    cfg.mc.progress_interval_seconds = 15*60;

    switch lower(cfg.profile)
        case 'local_smoke'
            cfg.n_list = 8;
            cfg.ebno_db = [0 6];
            cfg.mc.min_frames = 1;
            cfg.mc.target_false_positives = 1;
            cfg.mc.target_false_negatives = 1;
            cfg.mc.max_trials_per_class = 1e4;
            cfg.mc.max_frames = 2;
            cfg.mc.max_runtime_seconds = 5*60;
            cfg.memory.frames_per_batch = 1;

        case 'server_pilot'
            cfg.n_list = [44 50];
            cfg.ebno_db = 0:2:10;
            cfg.mc.min_frames = 25;
            cfg.mc.target_false_positives = 50;
            cfg.mc.target_false_negatives = 50;
            cfg.mc.max_trials_per_class = 2e5;
            cfg.mc.max_frames = 500;
            cfg.mc.max_runtime_seconds = 6*60*60;
            cfg.memory.frames_per_batch = 4;

        case 'server_full'
            cfg.n_list = 4:2:24;
            cfg.ebno_db = 0:1:10;
            cfg.mc.min_frames = 100;
            cfg.mc.target_false_positives = 200;
            cfg.mc.target_false_negatives = 200;
            % With zero observed errors this gives the rule-of-three
            % one-sided 95% upper bound 3e-6 for each conditional rate.
            cfg.mc.max_trials_per_class = 1e6;
            cfg.mc.max_frames = 5000;
            % Leave a full day of scheduler margin on the 72-hour job.
            cfg.mc.max_runtime_seconds = 48*60*60;
            cfg.memory.frames_per_batch = 4;

        otherwise
            error('Unknown noisy-channel profile "%s".', cfg.profile);
    end

    cfg.paths.results_dir = fullfile('results', 'noisy_channel', cfg.profile, sprintf('E2_%.2f', cfg.bfc.E2), cfg.bfc.func_type);
    cfg.paths.bank_dir = fullfile(cfg.paths.results_dir, 'source_banks');
    cfg.paths.point_dir = fullfile(cfg.paths.results_dir, 'points');
end
