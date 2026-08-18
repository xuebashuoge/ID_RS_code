function aggregate = plot_noisy_channel_tradeoff_results(configs, zero_mode)
%PLOT_NOISY_CHANNEL_TRADEOFF_RESULTS Plot controlled E2/rate experiments.
%
%   Three recommended views are produced:
%     1. decision error versus Eb/N0, with one curve per sweep value;
%     2. decision error versus parallel BFC rate, with one curve per SNR;
%     3. for an LDPC-rate sweep, decision error versus physical channel
%        uses per BFC decision, with one curve per SNR.
%
%   Every figure contains one tile for each n so n=[4 6 8] can be compared
%   without treating an LDPC frame as one identification message.

    if nargin < 2
        zero_mode = 'rule_of_three';
    end
    if ~iscell(configs) || isempty(configs)
        error('CONFIGS must be a nonempty cell array of sweep configurations.');
    end

    aggregate = collect_points(configs);
    if isempty(aggregate)
        error('No completed tradeoff result points were found.');
    end

    aggregate_dir = configs{1}.experiment.aggregate_dir;
    if ~exist(aggregate_dir, 'dir')
        mkdir(aggregate_dir);
    end
    cfg = configs{1};
    save(fullfile(aggregate_dir, 'summary_noisy_channel_tradeoff.mat'), ...
        'aggregate', 'configs');

    channels = unique({aggregate.channel}, 'stable');
    for channel_index = 1:numel(channels)
        channel_type = channels{channel_index};
        channel_points = aggregate(strcmpi({aggregate.channel}, channel_type));
        decision_metrics = {'balanced', 'fpr', 'fnr', 'max'};
        for metric_index = 1:numel(decision_metrics)
            metric_name = decision_metrics{metric_index};
            plot_ebno_view(channel_points, cfg, aggregate_dir, ...
                zero_mode, metric_name);
            plot_resource_view(channel_points, cfg, aggregate_dir, ...
                'parallel_bfc_rate', zero_mode, metric_name);
            if strcmp(cfg.experiment.type, 'ldpc_rate')
                plot_resource_view(channel_points, cfg, aggregate_dir, ...
                    'channel_uses_per_bfc_decision', zero_mode, metric_name);
            end
        end
    end
end

function aggregate = collect_points(configs)
    aggregate = struct([]);
    for config_index = 1:numel(configs)
        cfg = configs{config_index};
        for n = cfg.n_list
            for channel_index = 1:numel(cfg.channel_types)
                channel_type = cfg.channel_types{channel_index};
                for ebno_db = cfg.ebno_db
                    filename = noisy_channel_result_file( ...
                        cfg, n, channel_type, ebno_db);
                    if ~isfile(filename)
                        continue;
                    end
                    loaded = load(filename, 'result');
                    if ~isfield(loaded, 'result') || ...
                            ~isfield(loaded.result, 'complete') || ...
                            ~loaded.result.complete
                        continue;
                    end

                    result = loaded.result;
                    rates = noisy_channel_rate_metadata(result);
                    coded_fpr = result.metrics.coded.fpr;
                    coded_fnr = result.metrics.coded.fnr;
                    entry = struct( ...
                        'sweep_type', cfg.experiment.type, ...
                        'sweep_value', cfg.experiment.value, ...
                        'sweep_label', cfg.experiment.display_label, ...
                        'n', double(n), ...
                        'K', double(result.derived.K), ...
                        'm', double(result.derived.m), ...
                        'channel', lower(channel_type), ...
                        'ebno_db', double(ebno_db), ...
                        'E2', double(cfg.bfc.E2), ...
                        'ldpc_code_rate', rates.ldpc_code_rate, ...
                        'ldpc_payload_rate', rates.ldpc_payload_rate, ...
                        'noiseless_bfc_rate', rates.noiseless_bfc_rate, ...
                        'parallel_bfc_rate', rates.parallel_bfc_rate, ...
                        'channel_uses_per_bfc_decision', ...
                            rates.channel_uses_per_bfc_decision, ...
                        'coded_weighted_error', ...
                            result.metrics.coded.weighted_error, ...
                        'coded_empirical_decision_error', ...
                            result.metrics.coded.balanced_error, ...
                        'coded_fpr', coded_fpr, ...
                        'coded_fnr', coded_fnr, ...
                        'coded_max_conditional_error', ...
                            max(coded_fpr, coded_fnr), ...
                        'intrinsic_error', decomposition_value( ...
                            result, 'intrinsic_error'), ...
                        'channel_created_error', decomposition_value( ...
                            result, 'channel_created_error'), ...
                        'channel_corrected_intrinsic_error', ...
                            decomposition_value(result, ...
                            'channel_corrected_intrinsic_error'), ...
                        'noiseless_weighted_error', ...
                            result.metrics.noiseless.weighted_error, ...
                        'noiseless_empirical_decision_error', ...
                            result.metrics.noiseless.balanced_error, ...
                        'coded_tuple_error', ...
                            result.metrics.coded_tuple_error_rate, ...
                        'ldpc_ber', result.metrics.ldpc_payload_ber, ...
                        'ldpc_fer', result.metrics.ldpc_fer, ...
                        'tuples', double(result.tuples), ...
                        'frames', double(result.frames), ...
                        'actual_zero_trials', ...
                            double(result.counts.coded.actual_zero), ...
                        'actual_one_trials', ...
                            double(result.counts.coded.actual_one));
                    if isempty(aggregate)
                        aggregate = entry;
                    else
                        aggregate(end+1) = orderfields(entry, aggregate); %#ok<AGROW>
                    end
                end
            end
        end
    end
end

function plot_ebno_view(points, cfg, output_dir, zero_mode, metric_name)
    n_values = unique([points.n]);
    sweep_values = unique([points.sweep_value], 'stable');
    colors = lines(numel(sweep_values));
    fig = figure('Visible', 'off', 'Color', 'w', ...
        'Position', [100 100 max(520, 500*numel(n_values)) 450]);
    layout = tiledlayout(fig, 1, numel(n_values), ...
        'TileSpacing', 'compact', 'Padding', 'compact');

    for n_index = 1:numel(n_values)
        n = n_values(n_index);
        ax = nexttile(layout);
        hold(ax, 'on');
        for value_index = 1:numel(sweep_values)
            value = sweep_values(value_index);
            selected = points([points.n] == n & ...
                approximately_equal([points.sweep_value], value));
            if isempty(selected)
                continue;
            end
            [~, order] = sort([selected.ebno_db]);
            selected = selected(order);
            [y, trials] = decision_metric_values(selected, metric_name);
            y = prepare_zeros(y, trials, zero_mode);
            label = sweep_legend(selected(1));
            semilogy(ax, [selected.ebno_db], y, 'o-', ...
                'Color', colors(value_index, :), 'LineWidth', 1.8, ...
                'DisplayName', label);
        end
        style_axis(ax, 'E_b/N_0 (dB)');
        set(ax, 'YScale', 'log');
        title(ax, sprintf('n=%d', n));
        legend(ax, 'Location', 'best');
    end

    sgtitle(layout, sprintf('%s: BFC %s across %s', ...
        upper(points(1).channel), metric_title(metric_name), ...
        sweep_title(cfg.experiment.type)));
    if strcmp(metric_name, 'balanced')
        filename = sprintf('%s_%s_error_vs_ebno.png', ...
            cfg.experiment.type, lower(points(1).channel));
    else
        filename = sprintf('%s_%s_%s_error_vs_ebno.png', ...
            cfg.experiment.type, lower(points(1).channel), metric_name);
    end
    output_file = fullfile(output_dir, filename);
    exportgraphics(fig, output_file, 'Resolution', 300);
    close(fig);
    fprintf('Saved %s\n', output_file);
end

function plot_resource_view(points, cfg, output_dir, resource_name, zero_mode, metric_name)
    n_values = unique([points.n]);
    snr_values = select_snr_curves(unique([points.ebno_db]));
    colors = turbo(numel(snr_values));
    fig = figure('Visible', 'off', 'Color', 'w', ...
        'Position', [100 100 max(520, 500*numel(n_values)) 450]);
    layout = tiledlayout(fig, 1, numel(n_values), ...
        'TileSpacing', 'compact', 'Padding', 'compact');

    for n_index = 1:numel(n_values)
        n = n_values(n_index);
        ax = nexttile(layout);
        hold(ax, 'on');
        for snr_index = 1:numel(snr_values)
            ebno_db = snr_values(snr_index);
            selected = points([points.n] == n & ...
                approximately_equal([points.ebno_db], ebno_db));
            if isempty(selected)
                continue;
            end
            x = [selected.(resource_name)];
            [x, order] = sort(x);
            selected = selected(order);
            [y, trials] = decision_metric_values(selected, metric_name);
            y = prepare_zeros(y, trials, zero_mode);
            semilogy(ax, x, y, 'o-', ...
                'Color', colors(snr_index, :), 'LineWidth', 1.8, ...
                'DisplayName', sprintf('E_b/N_0=%g dB', ebno_db));
        end
        style_axis(ax, resource_label(resource_name));
        set(ax, 'YScale', 'log');
        title(ax, sprintf('n=%d', n));
        legend(ax, 'Location', 'best');
    end

    sgtitle(layout, sprintf('%s: %s-resource tradeoff (%s sweep)', ...
        upper(points(1).channel), metric_title(metric_name), ...
        sweep_title(cfg.experiment.type)));
    if strcmp(metric_name, 'balanced')
        filename = sprintf('%s_%s_error_vs_%s.png', ...
            cfg.experiment.type, lower(points(1).channel), resource_name);
    else
        filename = sprintf('%s_%s_%s_error_vs_%s.png', ...
            cfg.experiment.type, lower(points(1).channel), ...
            metric_name, resource_name);
    end
    output_file = fullfile(output_dir, filename);
    exportgraphics(fig, output_file, 'Resolution', 300);
    close(fig);
    fprintf('Saved %s\n', output_file);
end

function label = sweep_legend(point)
    switch point.sweep_type
        case 'e2'
            label = sprintf('E_2=%.3g, K=%d, R_{\\Sigma}=%.4f', ...
                point.E2, point.K, point.parallel_bfc_rate);
        case 'ldpc_rate'
            label = sprintf('R_c=%.4g, \\nu=%.3g, R_{\\Sigma}=%.4f', ...
                point.ldpc_code_rate, ...
                point.channel_uses_per_bfc_decision, ...
                point.parallel_bfc_rate);
        otherwise
            label = point.sweep_label;
    end
end

function title_text = sweep_title(sweep_type)
    if strcmp(sweep_type, 'e2')
        title_text = 'E_2';
    else
        title_text = 'LDPC rate';
    end
end

function label = resource_label(resource_name)
    switch resource_name
        case 'parallel_bfc_rate'
            label = 'Parallel BFC rate R_{\Sigma} per channel use';
        case 'channel_uses_per_bfc_decision'
            label = 'Physical channel uses per BFC decision \nu';
        otherwise
            label = strrep(resource_name, '_', ' ');
    end
end

function values = select_snr_curves(values)
    values = sort(unique(values));
    max_curves = 6;
    if numel(values) > max_curves
        indices = unique(round(linspace(1, numel(values), max_curves)));
        values = values(indices);
    end
end

function mask = approximately_equal(values, target)
    mask = abs(double(values) - double(target)) <= ...
        1e-10 * max(1, abs(double(target)));
end

function style_axis(ax, x_label)
    grid(ax, 'on');
    xlabel(ax, x_label);
    ylabel(ax, 'Conditional/average error probability');
end

function [values, trials] = decision_metric_values(points, metric_name)
    switch metric_name
        case 'balanced'
            values = [points.coded_empirical_decision_error];
            trials = [points.tuples];
        case 'fpr'
            values = [points.coded_fpr];
            trials = [points.actual_zero_trials];
        case 'fnr'
            values = [points.coded_fnr];
            trials = [points.actual_one_trials];
        case 'max'
            values = [points.coded_max_conditional_error];
            trials = min([points.actual_zero_trials], ...
                [points.actual_one_trials]);
        otherwise
            error('Unknown BFC decision metric "%s".', metric_name);
    end
end

function value = metric_title(metric_name)
    switch metric_name
        case 'balanced'
            value = 'balanced average error';
        case 'fpr'
            value = 'false-positive rate';
        case 'fnr'
            value = 'false-negative rate';
        case 'max'
            value = 'max(FPR,FNR)';
    end
end

function value = decomposition_value(result, field_name)
    if isfield(result, 'metrics') && ...
            isfield(result.metrics, 'decomposition') && ...
            isfield(result.metrics.decomposition, field_name)
        value = result.metrics.decomposition.(field_name);
    else
        value = NaN;
    end
end

function values = prepare_zeros(values, trials, zero_mode)
    values = double(values);
    zero_mask = values <= 0;
    switch lower(zero_mode)
        case 'omit'
            values(zero_mask) = NaN;
        case 'rule_of_three'
            trials = double(trials);
            values(zero_mask) = min( ...
                1, 3 ./ max(1, trials(zero_mask)));
        otherwise
            error('Unknown zero plotting mode "%s".', zero_mode);
    end
end
