%RUN_NOISY_CHANNEL_TRADEOFF_ARRAY_TASK SLURM entry point for sweep points.
sweep_type = getenv_default('BFC_SWEEP_TYPE', 'e2');
profile = getenv_default('BFC_SWEEP_PROFILE', 'server_full');
func_type = getenv_default('BFC_FUNC_TYPE', 'id');
configs = noisy_channel_tradeoff_configs(sweep_type, profile, func_type);

task_id = str2double(getenv('SLURM_ARRAY_TASK_ID'));
if isnan(task_id)
    error('SLURM_ARRAY_TASK_ID is not set.');
end

num_n = numel(configs{1}.n_list);
num_channels = numel(configs{1}.channel_types);
num_snr = numel(configs{1}.ebno_db);
points_per_config = num_n * num_channels * num_snr;
total_points = numel(configs) * points_per_config;
if task_id < 0 || task_id >= total_points
    error('Simulation array index %d is outside 0..%d.', ...
        task_id, total_points-1);
end

config_index = floor(task_id / points_per_config) + 1;
remainder = mod(task_id, points_per_config);
points_per_n = num_channels * num_snr;
n_index = floor(remainder / points_per_n) + 1;
remainder = mod(remainder, points_per_n);
channel_index = floor(remainder / num_snr) + 1;
snr_index = mod(remainder, num_snr) + 1;

cfg = configs{config_index};
n = cfg.n_list(n_index);
channel_type = cfg.channel_types{channel_index};
ebno_db = cfg.ebno_db(snr_index);
bank = prepare_bfc_source_bank( ...
    cfg, n, noisy_channel_bank_file(cfg, n));
run_noisy_channel_point(cfg, bank, channel_type, ebno_db, ...
    noisy_channel_result_file(cfg, n, channel_type, ebno_db));

function value = getenv_default(name, default_value)
    value = getenv(name);
    if isempty(value)
        value = default_value;
    end
end
