function manifest = replot_noisy_channel_tradeoff_by_setting( ...
        sweep_type, profile, func_type, error_metric, zero_mode)
%REPLOT_NOISY_CHANNEL_TRADEOFF_BY_SETTING Traditional Eb/N0 replot.
%
%   MANIFEST = REPLOT_NOISY_CHANNEL_TRADEOFF_BY_SETTING(TYPE, PROFILE,
%   FUNC_TYPE) reads completed point files from a tradeoff sweep and makes
%   one image for every E2 (TYPE="e2") or every LDPC code rate
%   (TYPE="ldpc_rate"). Each image has
%
%       x-axis: Eb/N0 (dB)
%       y-axis: end-to-end BFC decision error probability
%       curves: different n, labelled by physical channel uses/decision.
%
%   No simulation is run and no point file is modified. The default error
%   metric is "balanced", i.e. (FP+FN)/number of balanced Monte Carlo
%   trials. ERROR_METRIC can also be "fpr", "fnr", "max", "weighted",
%   "tuple", "ber", or "fer". ZERO_MODE is "omit" (default) or
%   "rule_of_three".
%
%   Examples:
%     replot_noisy_channel_tradeoff_by_setting('e2','server_full','id')
%     replot_noisy_channel_tradeoff_by_setting( ...
%         'ldpc_rate','server_full','id','balanced','rule_of_three')

    if nargin < 1 || isempty(sweep_type)
        sweep_type = 'e2';
    end
    if nargin < 2 || isempty(profile)
        profile = 'server_full';
    end
    if nargin < 3 || isempty(func_type)
        func_type = 'id';
    end
    if nargin < 4 || isempty(error_metric)
        error_metric = 'balanced';
    end
    if nargin < 5 || isempty(zero_mode)
        zero_mode = 'omit';
    end

    sweep_type = normalize_sweep_type(sweep_type);
    error_metric = lower(char(error_metric));
    zero_mode = lower(char(zero_mode));
    validate_metric(error_metric);
    if ~any(strcmp(zero_mode, {'omit', 'rule_of_three'}))
        error('ZERO_MODE must be "omit" or "rule_of_three".');
    end

    sweep_dir = fullfile('results', 'noisy_channel_tradeoffs', ...
        char(profile), char(func_type), sweep_type);
    if ~exist(sweep_dir, 'dir')
        error('Tradeoff result directory does not exist: %s', sweep_dir);
    end

    config_files = dir(fullfile(sweep_dir, '*', 'configuration.mat'));
    if isempty(config_files)
        error('No saved tradeoff configurations were found under %s.', sweep_dir);
    end

    manifest = struct([]);
    for config_index = 1:numel(config_files)
        config_file = fullfile( ...
            config_files(config_index).folder, config_files(config_index).name);
        saved = load(config_file, 'cfg');
        if ~isfield(saved, 'cfg')
            warning('Skipping configuration file without cfg: %s', config_file);
            continue;
        end
        cfg = saved.cfg;
        cfg.paths.results_dir = config_files(config_index).folder;
        cfg.paths.point_dir = fullfile(cfg.paths.results_dir, 'points');

        points = load_completed_points(cfg.paths.point_dir);
        if isempty(points)
            warning('No completed point files found in %s.', cfg.paths.point_dir);
            continue;
        end

        channels = unique({points.channel}, 'stable');
        for channel_index = 1:numel(channels)
            channel_type = channels{channel_index};
            channel_points = points(strcmpi({points.channel}, channel_type));
            [output_file, n_values] = plot_one_setting( ...
                channel_points, cfg, sweep_type, channel_type, ...
                error_metric, zero_mode);

            entry = struct( ...
                'sweep_type', sweep_type, ...
                'setting_value', setting_value(cfg, sweep_type), ...
                'channel', channel_type, ...
                'n_values', n_values, ...
                'error_metric', error_metric, ...
                'zero_mode', zero_mode, ...
                'output_file', output_file);
            if isempty(manifest)
                manifest = entry;
            else
                manifest(end+1) = orderfields(entry, manifest); %#ok<AGROW>
            end
        end
    end

    if isempty(manifest)
        error('No figures were produced because no completed results were found.');
    end

    [~, order] = sort([manifest.setting_value]);
    manifest = manifest(order);
end

function points = load_completed_points(point_dir)
    points = struct([]);
    if ~exist(point_dir, 'dir')
        return;
    end
    files = dir(fullfile(point_dir, 'result_n_*.mat'));
    for file_index = 1:numel(files)
        filename = fullfile(files(file_index).folder, files(file_index).name);
        saved = load(filename, 'result');
        if ~isfield(saved, 'result') || ...
                ~isfield(saved.result, 'complete') || ~saved.result.complete
            continue;
        end
        result = saved.result;
        rates = noisy_channel_rate_metadata(result);
        entry = struct( ...
            'result', result, ...
            'n', double(result.scenario.n), ...
            'channel', lower(result.scenario.channel), ...
            'ebno_db', double(result.scenario.ebno_db), ...
            'channel_uses_per_bfc_decision', ...
                rates.channel_uses_per_bfc_decision, ...
            'parallel_bfc_rate', rates.parallel_bfc_rate);
        if isempty(points)
            points = entry;
        else
            points(end+1) = orderfields(entry, points); %#ok<AGROW>
        end
    end
end

function [output_file, n_values] = plot_one_setting( ...
        points, cfg, sweep_type, channel_type, error_metric, zero_mode)
    n_values = sort(unique([points.n]));
    colors = lines(numel(n_values));
    markers = {'o', 's', '^', 'd', 'v', '>', '<', 'p', 'h'};

    fig = figure('Visible', 'off', 'Color', 'w', ...
        'Position', [100 100 780 540]);
    ax = axes(fig);
    hold(ax, 'on');

    for n_index = 1:numel(n_values)
        n = n_values(n_index);
        selected = points([points.n] == n);
        [~, order] = sort([selected.ebno_db]);
        selected = selected(order);

        [errors, trials] = extract_error(selected, error_metric);
        errors = prepare_zero_values(errors, trials, zero_mode);
        marker = markers{mod(n_index-1, numel(markers))+1};
        display_name = sprintf('n=%d, \\nu=%.3g uses/decision', ...
            n, selected(1).channel_uses_per_bfc_decision);
        semilogy(ax, [selected.ebno_db], errors, ...
            'Color', colors(n_index, :), 'Marker', marker, ...
            'MarkerSize', 7, 'LineWidth', 1.8, ...
            'DisplayName', display_name);
    end

    grid(ax, 'on');
    box(ax, 'on');
    set(ax, 'YScale', 'log');
    xlabel(ax, 'E_b/N_0 (dB)');
    ylabel(ax, metric_label(error_metric));
    title(ax, sprintf('%s, %s, %s', upper(channel_type), ...
        setting_label(cfg, sweep_type), zero_note(zero_mode)));
    legend(ax, 'Location', 'best');

    output_file = fullfile(cfg.paths.results_dir, sprintf( ...
        'replot_%s_error_vs_ebno_compare_n_%s_%s.png', ...
        error_metric, lower(channel_type), zero_mode));
    exportgraphics(fig, output_file, 'Resolution', 300);
    close(fig);
    fprintf('Saved %s\n', output_file);
end

function [errors, trials] = extract_error(points, error_metric)
    results = {points.result};
    switch error_metric
        case 'balanced'
            errors = cellfun(@(x) x.metrics.coded.balanced_error, results);
            trials = cellfun(@(x) x.counts.coded.total, results);
        case 'weighted'
            errors = cellfun(@(x) x.metrics.coded.weighted_error, results);
            trials = cellfun(@(x) x.counts.coded.total, results);
        case 'fpr'
            errors = cellfun(@(x) x.metrics.coded.fpr, results);
            trials = cellfun(@(x) x.counts.coded.actual_zero, results);
        case 'fnr'
            errors = cellfun(@(x) x.metrics.coded.fnr, results);
            trials = cellfun(@(x) x.counts.coded.actual_one, results);
        case 'max'
            errors = cellfun(@(x) max( ...
                x.metrics.coded.fpr, x.metrics.coded.fnr), results);
            trials = cellfun(@(x) min( ...
                x.counts.coded.actual_zero, ...
                x.counts.coded.actual_one), results);
        case 'tuple'
            errors = cellfun(@(x) x.metrics.coded_tuple_error_rate, results);
            trials = cellfun(@(x) x.tuples, results);
        case 'ber'
            errors = cellfun(@(x) x.metrics.ldpc_payload_ber, results);
            trials = cellfun( ...
                @(x) x.channel_counts.ldpc_payload_bits, results);
        case 'fer'
            errors = cellfun(@(x) x.metrics.ldpc_fer, results);
            trials = cellfun(@(x) x.frames, results);
    end
end

function values = prepare_zero_values(values, trials, zero_mode)
    values = double(values);
    zero_mask = values <= 0;
    if strcmp(zero_mode, 'omit')
        values(zero_mask) = NaN;
    else
        values(zero_mask) = min( ...
            1, 3 ./ max(1, double(trials(zero_mask))));
    end
end

function label = metric_label(error_metric)
    switch error_metric
        case 'balanced'
            label = 'BFC decision error, (FP + FN) / trials';
        case 'weighted'
            label = 'Prior-weighted BFC decision error probability';
        case 'fpr'
            label = 'BFC false-positive rate';
        case 'fnr'
            label = 'BFC false-negative rate';
        case 'max'
            label = 'BFC max(FPR,FNR)';
        case 'tuple'
            label = 'Coded BFC tuple error rate';
        case 'ber'
            label = 'LDPC payload BER';
        case 'fer'
            label = 'LDPC FER';
    end
end

function label = setting_label(cfg, sweep_type)
    if strcmp(sweep_type, 'e2')
        label = sprintf('E_2=%.3g, R_c=%.4g', ...
            cfg.bfc.E2, cfg.ldpc.rate);
    else
        label = sprintf('R_c=%.4g, E_2=%.3g', ...
            cfg.ldpc.rate, cfg.bfc.E2);
    end
end

function value = setting_value(cfg, sweep_type)
    if strcmp(sweep_type, 'e2')
        value = double(cfg.bfc.E2);
    else
        value = double(cfg.ldpc.rate);
    end
end

function text = zero_note(zero_mode)
    if strcmp(zero_mode, 'omit')
        text = 'zero-error points omitted';
    else
        text = 'zero-error points shown at 3/trials';
    end
end

function sweep_type = normalize_sweep_type(sweep_type)
    sweep_type = lower(strrep(char(sweep_type), '-', '_'));
    if strcmp(sweep_type, 'rate')
        sweep_type = 'ldpc_rate';
    end
    if ~any(strcmp(sweep_type, {'e2', 'ldpc_rate'}))
        error('TYPE must be "e2" or "ldpc_rate".');
    end
end

function validate_metric(error_metric)
    valid_metrics = {'balanced', 'fpr', 'fnr', 'max', ...
        'weighted', 'tuple', 'ber', 'fer'};
    if ~any(strcmp(error_metric, valid_metrics))
        error('ERROR_METRIC must be one of: %s.', ...
            strjoin(valid_metrics, ', '));
    end
end
