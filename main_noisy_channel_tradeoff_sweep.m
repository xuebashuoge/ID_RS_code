function output = main_noisy_channel_tradeoff_sweep( ...
        sweep_type, profile, func_type, sweep_values)
%MAIN_NOISY_CHANNEL_TRADEOFF_SWEEP Run an E2 or LDPC-rate tradeoff sweep.

    if nargin < 1
        sweep_type = 'e2';
    end
    if nargin < 2
        profile = [];
    end
    if nargin < 3
        func_type = [];
    end
    if nargin < 4
        sweep_values = [];
    end

    configs = noisy_channel_tradeoff_configs( ...
        sweep_type, profile, func_type, sweep_values);
    summaries = cell(size(configs));
    for config_index = 1:numel(configs)
        cfg = configs{config_index};
        fprintf('\n=== %s (%d/%d) ===\n', ...
            cfg.experiment.display_label, config_index, numel(configs));
        summaries{config_index} = run_noisy_channel_configuration(cfg);
    end

    aggregate_summary = plot_noisy_channel_tradeoff_results(configs);
    output = struct('configs', {configs}, 'summaries', {summaries}, ...
        'aggregate_summary', aggregate_summary);
end
