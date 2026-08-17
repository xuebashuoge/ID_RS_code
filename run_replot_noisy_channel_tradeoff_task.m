%RUN_REPLOT_NOISY_CHANNEL_TRADEOFF_TASK Standalone SLURM replot entry point.
sweep_type = getenv_default('BFC_SWEEP_TYPE', 'e2');
profile = getenv_default('BFC_SWEEP_PROFILE', 'server_full');
func_type = getenv_default('BFC_FUNC_TYPE', 'id');
error_metric = getenv_default('BFC_ERROR_METRIC', 'balanced');
zero_mode = getenv_default('BFC_ZERO_MODE', 'omit');

fprintf(['Replotting sweep=%s, profile=%s, function=%s, ' ...
    'metric=%s, zeros=%s\n'], sweep_type, profile, func_type, ...
    error_metric, zero_mode);
manifest = replot_noisy_channel_tradeoff_by_setting( ...
    sweep_type, profile, func_type, error_metric, zero_mode);

function value = getenv_default(name, default_value)
    value = getenv(name);
    if isempty(value)
        value = default_value;
    end
end
