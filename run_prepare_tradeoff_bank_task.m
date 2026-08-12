%RUN_PREPARE_TRADEOFF_BANK_TASK SLURM entry point for tradeoff source banks.
sweep_type = getenv_default('BFC_SWEEP_TYPE', 'e2');
profile = getenv_default('BFC_SWEEP_PROFILE', 'server_full');
func_type = getenv_default('BFC_FUNC_TYPE', 'id');
configs = noisy_channel_tradeoff_configs(sweep_type, profile, func_type);

task_id = str2double(getenv('SLURM_ARRAY_TASK_ID'));
if isnan(task_id)
    error('SLURM_ARRAY_TASK_ID is not set.');
end
num_n = numel(configs{1}.n_list);
total_tasks = numel(configs) * num_n;
if task_id < 0 || task_id >= total_tasks
    error('Preparation array index %d is outside 0..%d.', ...
        task_id, total_tasks-1);
end

config_index = floor(task_id / num_n) + 1;
n_index = mod(task_id, num_n) + 1;
cfg = configs{config_index};
n = cfg.n_list(n_index);
if ~exist(cfg.paths.results_dir, 'dir')
    mkdir(cfg.paths.results_dir);
end
save(fullfile(cfg.paths.results_dir, 'configuration.mat'), 'cfg');
prepare_bfc_source_bank(cfg, n, noisy_channel_bank_file(cfg, n));

function value = getenv_default(name, default_value)
    value = getenv(name);
    if isempty(value)
        value = default_value;
    end
end
