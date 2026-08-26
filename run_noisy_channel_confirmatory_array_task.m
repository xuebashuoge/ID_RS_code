%RUN_NOISY_CHANNEL_CONFIRMATORY_ARRAY_TASK Fixed-sample SLURM entry point.
experiment = getenv_default('BFC_CONFIRMATORY_EXPERIMENT', 'waterfall');
configs = noisy_channel_confirmatory_configs(experiment);
task_id = str2double(getenv('SLURM_ARRAY_TASK_ID'));
if isnan(task_id)
    error('SLURM_ARRAY_TASK_ID is not set.');
end
snr_count = numel(configs{1}.ebno_db);
total_points = numel(configs) * snr_count;
if task_id < 0 || task_id >= total_points
    error('Simulation array index %d is outside 0..%d.', ...
        task_id, total_points-1);
end
config_index = floor(task_id/snr_count) + 1;
snr_index = mod(task_id, snr_count) + 1;
cfg = configs{config_index};
if ~exist(cfg.paths.results_dir, 'dir')
    mkdir(cfg.paths.results_dir);
end
save(fullfile(cfg.paths.results_dir, 'configuration.mat'), 'cfg');
n = cfg.n_list;
ebno_db = cfg.ebno_db(snr_index);
bank = prepare_bfc_source_bank( ...
    cfg, n, noisy_channel_bank_file(cfg, n));
run_noisy_channel_point(cfg, bank, 'awgn', ebno_db, ...
    noisy_channel_result_file(cfg, n, 'awgn', ebno_db));

function value = getenv_default(name, default_value)
    value = getenv(name);
    if isempty(value)
        value = default_value;
    end
end
