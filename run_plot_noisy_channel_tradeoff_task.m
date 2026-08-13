%RUN_PLOT_NOISY_CHANNEL_TRADEOFF_TASK Plot a completed SLURM tradeoff sweep.
sweep_type = getenv_default('BFC_SWEEP_TYPE', 'e2');
profile = getenv_default('BFC_SWEEP_PROFILE', 'server_full');
func_type = getenv_default('BFC_FUNC_TYPE', 'id');
configs = noisy_channel_tradeoff_configs(sweep_type, profile, func_type);

for config_index = 1:numel(configs)
    plot_noisy_channel_results(configs{config_index});
end
plot_noisy_channel_tradeoff_results(configs, 'omit');
replot_noisy_channel_tradeoff_by_setting( ...
    sweep_type, profile, func_type, 'balanced', 'omit');

function value = getenv_default(name, default_value)
    value = getenv(name);
    if isempty(value)
        value = default_value;
    end
end
