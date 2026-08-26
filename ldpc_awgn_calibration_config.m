function cfg = ldpc_awgn_calibration_config()
%LDPC_AWGN_CALIBRATION_CONFIG Fixed-sample DVB-S2 calibration sweep.

    cfg.version = 1;
    cfg.seed = 9173;
    cfg.rates = [1/3 2/5 1/2 3/5 2/3];
    cfg.algorithms = {'norm-min-sum', 'bp'};
    cfg.ebno_db = 0:0.25:3;
    cfg.frames = 200;
    cfg.frames_per_batch = 4;
    cfg.max_iterations = 50;
    cfg.min_sum_scaling = 0.75;
    cfg.multithreaded = true;
    cfg.results_dir = fullfile('results', ...
        'noisy_channel_confirmatory', 'ldpc_calibration');
    cfg.point_dir = fullfile(cfg.results_dir, 'points');
end
