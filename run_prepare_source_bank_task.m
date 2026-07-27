%RUN_PREPARE_SOURCE_BANK_TASK Entry point for the SLURM preparation array.
cfg = noisy_channel_config('server_full');
task_id = str2double(getenv('SLURM_ARRAY_TASK_ID'));
if isnan(task_id)
    error('SLURM_ARRAY_TASK_ID is not set.');
end
index = task_id + 1;
if index < 1 || index > numel(cfg.n_list)
    error('Preparation array index %d is outside 0..%d.', task_id, numel(cfg.n_list)-1);
end
n = cfg.n_list(index);
prepare_bfc_source_bank(cfg, n, noisy_channel_bank_file(cfg, n));
