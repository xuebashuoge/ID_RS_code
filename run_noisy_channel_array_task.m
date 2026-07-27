%RUN_NOISY_CHANNEL_ARRAY_TASK Entry point for the SLURM channel array.
cfg = noisy_channel_config('server_full');
task_id = str2double(getenv('SLURM_ARRAY_TASK_ID'));
if isnan(task_id)
    error('SLURM_ARRAY_TASK_ID is not set.');
end

num_snr = numel(cfg.ebno_db);
num_channels = numel(cfg.channel_types);
points_per_n = num_channels * num_snr;
total_points = numel(cfg.n_list) * points_per_n;
if task_id < 0 || task_id >= total_points
    error('Simulation array index %d is outside 0..%d.', task_id, total_points-1);
end

n_index = floor(task_id / points_per_n) + 1;
remainder = mod(task_id, points_per_n);
channel_index = floor(remainder / num_snr) + 1;
snr_index = mod(remainder, num_snr) + 1;

n = cfg.n_list(n_index);
channel_type = cfg.channel_types{channel_index};
ebno_db = cfg.ebno_db(snr_index);
loaded = load(noisy_channel_bank_file(cfg, n), 'bank');
run_noisy_channel_point(cfg, loaded.bank, channel_type, ebno_db, ...
    noisy_channel_result_file(cfg, n, channel_type, ebno_db));
