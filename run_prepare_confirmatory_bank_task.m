%RUN_PREPARE_CONFIRMATORY_BANK_TASK Prepare one fixed-sample source bank.
experiment = getenv_default('BFC_CONFIRMATORY_EXPERIMENT', 'waterfall');
[~, bank_configs] = noisy_channel_confirmatory_configs(experiment);
task_id = str2double(getenv('SLURM_ARRAY_TASK_ID'));
if isnan(task_id) || task_id < 0 || task_id >= numel(bank_configs)
    error('SLURM_ARRAY_TASK_ID must be in 0..%d.', numel(bank_configs)-1);
end
cfg = bank_configs{task_id+1};
if ~exist(cfg.paths.results_dir, 'dir')
    mkdir(cfg.paths.results_dir);
end
prepare_bfc_source_bank( ...
    cfg, cfg.n_list, noisy_channel_bank_file(cfg, cfg.n_list));

function value = getenv_default(name, default_value)
    value = getenv(name);
    if isempty(value)
        value = default_value;
    end
end
