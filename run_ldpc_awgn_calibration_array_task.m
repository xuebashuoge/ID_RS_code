%RUN_LDPC_AWGN_CALIBRATION_ARRAY_TASK SLURM entry point.
cfg = ldpc_awgn_calibration_config();
task_id = str2double(getenv('SLURM_ARRAY_TASK_ID'));
if isnan(task_id)
    error('SLURM_ARRAY_TASK_ID is not set.');
end
num_snr = numel(cfg.ebno_db);
num_algorithms = numel(cfg.algorithms);
points_per_rate = num_algorithms*num_snr;
total_points = numel(cfg.rates)*points_per_rate;
if task_id < 0 || task_id >= total_points
    error('Calibration array index %d is outside 0..%d.', ...
        task_id, total_points-1);
end
rate_index = floor(task_id/points_per_rate) + 1;
remainder = mod(task_id, points_per_rate);
algorithm_index = floor(remainder/num_snr) + 1;
snr_index = mod(remainder, num_snr) + 1;
rate = cfg.rates(rate_index);
algorithm = cfg.algorithms{algorithm_index};
ebno_db = cfg.ebno_db(snr_index);
run_ldpc_awgn_calibration_point(cfg, rate, algorithm, ebno_db, ...
    ldpc_awgn_calibration_result_file( ...
        cfg, rate, algorithm, ebno_db));
