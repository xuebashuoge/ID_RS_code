function outputs = plot_noisy_channel_confirmatory_results(experiment)
%PLOT_NOISY_CHANNEL_CONFIRMATORY_RESULTS Plot completed fixed-sample points.

    if nargin < 1 || isempty(experiment)
        experiment = 'waterfall';
    end
    configs = noisy_channel_confirmatory_configs(experiment);
    rows = collect_rows(configs);
    if isempty(rows)
        error('No complete confirmatory points were found for %s.', experiment);
    end
    output_dir = configs{1}.experiment.root_dir;
    table_out = struct2table(rows);
    outputs.csv = fullfile(output_dir, 'confirmatory_results.csv');
    writetable(table_out, outputs.csv);
    outputs.mat = fullfile(output_dir, 'confirmatory_results.mat');
    save(outputs.mat, 'rows', 'configs');
    switch lower(strrep(experiment, '-', '_'))
        case 'waterfall'
            outputs.figure = plot_waterfall(rows, output_dir);
        case 'rate_pareto'
            outputs.figure_uses = plot_pareto(rows, output_dir, ...
                'channel_uses_per_bfc_decision');
            outputs.figure_rate = plot_pareto(rows, output_dir, ...
                'parallel_bfc_rate');
    end
end

function rows = collect_rows(configs)
    rows = struct([]);
    for config_index = 1:numel(configs)
        cfg = configs{config_index};
        for ebno_db = cfg.ebno_db
            filename = noisy_channel_result_file( ...
                cfg, cfg.n_list, 'awgn', ebno_db);
            if ~isfile(filename)
                continue;
            end
            saved = load(filename, 'result');
            if ~saved.result.complete
                continue;
            end
            result = saved.result;
            rates = noisy_channel_rate_metadata(result);
            ci = result.metrics.coded.cluster_conditional_ci95;
            row = struct( ...
                'source_file', string(filename), ...
                'function_type', string(cfg.bfc.func_type), ...
                'function_label', string(cfg.experiment.function_label), ...
                'n', cfg.n_list, 'E2', cfg.bfc.E2, ...
                'ldpc_code_rate', cfg.ldpc.rate, ...
                'ebno_db', ebno_db, ...
                'false_positive_count', ...
                    result.counts.coded.false_positive, ...
                'negative_trials', result.counts.coded.actual_zero, ...
                'false_negative_count', ...
                    result.counts.coded.false_negative, ...
                'positive_trials', result.counts.coded.actual_one, ...
                'fpr', result.metrics.coded.fpr, ...
                'fnr', result.metrics.coded.fnr, ...
                'max_fpr_fnr', result.metrics.coded.max_conditional_error, ...
                'fp_plus_fn_over_trials', ...
                    result.metrics.coded.balanced_error, ...
                'max_ci95_lower', ci.max_simultaneous(1), ...
                'max_ci95_upper', ci.max_simultaneous(2), ...
                'channel_uses_per_bfc_decision', ...
                    rates.channel_uses_per_bfc_decision, ...
                'parallel_bfc_rate', rates.parallel_bfc_rate, ...
                'frames', result.frames, ...
                'stopping_mode', string(result.stopping.mode));
            if isempty(rows)
                rows = row;
            else
                rows(end+1) = orderfields(row, rows); %#ok<AGROW>
            end
        end
    end
end

function files = plot_waterfall(rows, output_dir)
    function_types = {'id', 'exact-threshold', 'rank'};
    fig = figure('Visible', 'off', 'Color', 'w', ...
        'Position', [100 100 1450 440]);
    layout = tiledlayout(fig, 1, 3, ...
        'TileSpacing', 'compact', 'Padding', 'compact');
    for function_index = 1:numel(function_types)
        selected = rows(strcmp([rows.function_type], ...
            function_types{function_index}));
        [~, order] = sort([selected.ebno_db]);
        selected = selected(order);
        x = [selected.ebno_db];
        y = [selected.max_fpr_fnr];
        low = [selected.max_ci95_lower];
        high = [selected.max_ci95_upper];
        ax = nexttile(layout);
        errorbar(ax, x, y, y-low, high-y, 'o-', ...
            'LineWidth', 1.6, 'CapSize', 4);
        set(ax, 'YScale', 'log');
        grid(ax, 'on');
        box(ax, 'on');
        xlabel(ax, 'E_b/N_0 (dB)');
        ylabel(ax, 'max(FPR, FNR)');
        title(ax, sprintf('%s, n=%d', ...
            selected(1).function_label, selected(1).n));
    end
    title(layout, 'Fixed-sample coded BFC waterfall with frame-cluster 95% CIs');
    files = export_figure_pair(fig, fullfile(output_dir, ...
        'confirmatory_waterfall_max_fpr_fnr'));
    close(fig);
end

function files = plot_pareto(rows, output_dir, resource_name)
    function_types = {'id', 'exact-threshold', 'rank'};
    snr_values = unique([rows.ebno_db]);
    colors = lines(numel(snr_values));
    fig = figure('Visible', 'off', 'Color', 'w', ...
        'Position', [100 100 1450 440]);
    layout = tiledlayout(fig, 1, 3, ...
        'TileSpacing', 'compact', 'Padding', 'compact');
    for function_index = 1:numel(function_types)
        ax = nexttile(layout);
        hold(ax, 'on');
        function_rows = rows(strcmp([rows.function_type], ...
            function_types{function_index}));
        for snr_index = 1:numel(snr_values)
            selected = function_rows(abs([function_rows.ebno_db]- ...
                snr_values(snr_index)) < 1e-12);
            [x, order] = sort([selected.(resource_name)]);
            selected = selected(order);
            y = [selected.max_fpr_fnr];
            semilogy(ax, x, y, 'o-', 'LineWidth', 1.5, ...
                'Color', colors(snr_index, :), 'DisplayName', sprintf( ...
                'E_b/N_0=%.1f dB', snr_values(snr_index)));
            if snr_index == 1
            for index = 1:numel(selected)
                horizontal_alignment = 'left';
                label = sprintf(' R_c=%.3g', ...
                    selected(index).ldpc_code_rate);
                if index == numel(selected)
                    horizontal_alignment = 'right';
                    label = sprintf('R_c=%.3g ', ...
                        selected(index).ldpc_code_rate);
                end
                label_y = y(index) * 10^(0.08 * ...
                    (index-(numel(selected)+1)/2));
                text(ax, x(index), label_y, label, 'FontSize', 7, ...
                    'Color', colors(snr_index, :), ...
                    'HorizontalAlignment', horizontal_alignment);
            end
            end
        end
        set(ax, 'YScale', 'log');
        grid(ax, 'on');
        box(ax, 'on');
        xlabel(ax, strrep(resource_name, '_', ' '));
        ylabel(ax, 'max(FPR, FNR)');
        title(ax, sprintf('%s, n=%d', ...
            function_rows(1).function_label, function_rows(1).n));
        legend(ax, 'Location', 'best');
    end
    title(layout, 'Fixed-sample LDPC-rate resource-reliability tradeoff');
    files = export_figure_pair(fig, fullfile(output_dir, ...
        ['confirmatory_pareto_' resource_name]));
    close(fig);
end
