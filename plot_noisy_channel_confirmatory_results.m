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
            d = result.derived;
            tag_exponent = cfg.bfc.E2;
            effective_exponent = rates.ldpc_code_rate*tag_exponent;
            effective_delta = rates.ldpc_code_rate/2-effective_exponent;
            scaling_denominator = asymptotic_scaling_denominator( ...
                cfg.bfc.func_type, cfg.bfc.params);
            rs_bound = min(1, double(result.bank_metadata.S)* ...
                (double(d.K)-1)/double(d.L));
            row = struct( ...
                'source_file', string(filename), ...
                'function_type', string(cfg.bfc.func_type), ...
                'function_label', string(cfg.experiment.function_label), ...
                'n', cfg.n_list, 'r', d.r, 'T', d.L, ...
                'K', d.K, 'm', d.m, 'S', result.bank_metadata.S, ...
                'E2', tag_exponent, ...
                'tag_error_exponent', tag_exponent, ...
                'effective_error_exponent', effective_exponent, ...
                'effective_delta', effective_delta, ...
                'asymptotic_parallel_rate_target', ...
                    effective_delta/scaling_denominator, ...
                'ldpc_code_rate', cfg.ldpc.rate, ...
                'ldpc_block_length', d.ldpc_N, ...
                'ldpc_information_length', d.ldpc_K, ...
                'ldpc_payload_rate', d.ldpc_payload_rate, ...
                'padding_efficiency', d.padding_efficiency, ...
                'tuples_per_frame', d.tuples_per_frame, ...
                'ebno_db', ebno_db, ...
                'channel_uses_per_bfc_decision', ...
                    rates.channel_uses_per_bfc_decision, ...
                'parallel_bfc_rate', rates.parallel_bfc_rate, ...
                'rs_worst_case_fpr_bound', rs_bound, ...
                'frames', result.frames, ...
                'stopping_mode', string(result.stopping.mode));
            row = append_decision_fields(row, result, 'coded');
            row = append_decision_fields(row, result, 'uncoded');
            row = append_decision_fields(row, result, 'noiseless');
            row.ldpc_frame_errors = ...
                result.channel_counts.ldpc_frame_errors;
            row.ldpc_fer = result.metrics.ldpc_fer;
            row.ldpc_payload_ber = result.metrics.ldpc_payload_ber;
            row.mean_ldpc_iterations = result.metrics.mean_ldpc_iterations;
            row.coded_tuple_error_rate = result.metrics.coded_tuple_error_rate;
            row.empirical_fpr_union_reference = min(1, ...
                result.metrics.noiseless.fpr+result.metrics.ldpc_fer);
            row.worst_case_fpr_union_reference = min(1, ...
                rs_bound+result.metrics.ldpc_fer);
            row.fnr_fer_reference = result.metrics.ldpc_fer;
            row.empirical_fpr_union_excess = result.metrics.coded.fpr- ...
                row.empirical_fpr_union_reference;
            row.worst_case_fpr_union_excess = result.metrics.coded.fpr- ...
                row.worst_case_fpr_union_reference;
            row.fnr_fer_excess = result.metrics.coded.fnr- ...
                row.fnr_fer_reference;
            row.intrinsic_balanced_error = ...
                result.metrics.decomposition.intrinsic_error;
            row.channel_created_balanced_error = ...
                result.metrics.decomposition.channel_created_error;
            row.channel_corrected_intrinsic_error = ...
                result.metrics.decomposition.channel_corrected_intrinsic_error;
            if isempty(rows)
                rows = row;
            else
                rows(end+1) = orderfields(row, rows); %#ok<AGROW>
            end
        end
    end
end

function row = append_decision_fields(row, result, prefix)
    counts = result.counts.(prefix);
    metrics = result.metrics.(prefix);
    ci = metrics.cluster_conditional_ci95;
    row.([prefix '_false_positive_count']) = counts.false_positive;
    row.([prefix '_negative_trials']) = counts.actual_zero;
    row.([prefix '_false_negative_count']) = counts.false_negative;
    row.([prefix '_positive_trials']) = counts.actual_one;
    row.([prefix '_fpr']) = metrics.fpr;
    row.([prefix '_fnr']) = metrics.fnr;
    row.([prefix '_max_fpr_fnr']) = metrics.max_conditional_error;
    row.([prefix '_fp_plus_fn_over_trials']) = metrics.balanced_error;
    row.([prefix '_max_ci95_lower']) = ci.max(1);
    row.([prefix '_max_ci95_upper']) = ci.max(2);
    row.([prefix '_max_zero_event_tuple_upper95_legacy']) = ...
        ci.zero_event_tuple_upper95.max;
    [fpr_cluster_upper, fnr_cluster_upper, max_cluster_upper] = ...
        zero_event_cluster_upper(result, prefix);
    row.([prefix '_fpr_zero_event_cluster_upper95']) = fpr_cluster_upper;
    row.([prefix '_fnr_zero_event_cluster_upper95']) = fnr_cluster_upper;
    row.([prefix '_max_zero_event_cluster_upper95']) = max_cluster_upper;
end

function [fpr_upper, fnr_upper, max_upper] = ...
        zero_event_cluster_upper(result, prefix)
    fp_field = [prefix '_false_positive'];
    fn_field = [prefix '_false_negative'];
    false_positive = double(result.per_frame.(fp_field));
    false_negative = double(result.per_frame.(fn_field));
    fpr_upper = one_sided_zero_cluster_upper(false_positive);
    fnr_upper = one_sided_zero_cluster_upper(false_negative);
    if all(false_positive == 0) && all(false_negative == 0)
        max_upper = max(fpr_upper, fnr_upper);
    else
        max_upper = NaN;
    end
end

function upper = one_sided_zero_cluster_upper(cluster_counts)
    if all(cluster_counts == 0)
        % Conservative 95% bound at the independent LDPC-frame level.
        upper = 1-0.05^(1/numel(cluster_counts));
    else
        upper = NaN;
    end
end

function denominator = asymptotic_scaling_denominator(func_type, params)
    if strcmpi(func_type, 'exact-threshold')
        denominator = 1+params.beta;
    else
        % Identification and fixed-rank functions have constant support.
        denominator = 1;
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
        ax = nexttile(layout);
        hold(ax, 'on');
        plot_decision_curve(ax, x, selected, 'coded', ...
            [0 0.35 0.75], 'o', '-', 'BP-LDPC + BFC');
        plot_decision_curve(ax, x, selected, 'uncoded', ...
            [0.85 0.2 0.15], 'x', '-', 'Uncoded BPSK + BFC');
        plot_decision_curve(ax, x, selected, 'noiseless', ...
            [0.1 0.1 0.1], 'none', '--', 'Noiseless BFC');
        set(ax, 'YScale', 'log');
        grid(ax, 'on');
        box(ax, 'on');
        xlabel(ax, 'E_b/N_0 (dB)');
        ylabel(ax, 'max(FPR, FNR)');
        title(ax, sprintf('%s, n=%d', ...
            selected(1).function_label, selected(1).n));
        legend(ax, 'Location', 'best');
    end
    title(layout, ['BP-LDPC/BFC waterfall with fixed-sample ' ...
        'frame-cluster bootstrap 95% CIs']);
    files = export_figure_pair(fig, fullfile(output_dir, ...
        'confirmatory_waterfall_max_fpr_fnr'));
    close(fig);
end

function plot_decision_curve( ...
        ax, x, selected, prefix, color, marker, line_style, display_name)
    y = [selected.([prefix '_max_fpr_fnr'])];
    low = [selected.([prefix '_max_ci95_lower'])];
    high = [selected.([prefix '_max_ci95_upper'])];
    positive = y > 0;
    errorbar(ax, x(positive), y(positive), ...
        max(0, y(positive)-low(positive)), ...
        max(0, high(positive)-y(positive)), ...
        'Color', color, 'Marker', marker, 'LineStyle', line_style, ...
        'LineWidth', 1.5, 'CapSize', 3, 'DisplayName', display_name);
    zero = ~positive;
    if any(zero)
        upper = [selected.([prefix '_max_zero_event_cluster_upper95'])];
        valid_upper = zero & isfinite(upper) & upper > 0;
        semilogy(ax, x(valid_upper), upper(valid_upper), 'v', ...
            'LineStyle', 'none', 'Color', color, ...
            'HandleVisibility', 'off');
    end
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
            y = [selected.coded_max_fpr_fnr];
            low = [selected.coded_max_ci95_lower];
            high = [selected.coded_max_ci95_upper];
            positive = y > 0;
            errorbar(ax, x(positive), y(positive), ...
                max(0, y(positive)-low(positive)), ...
                max(0, high(positive)-y(positive)), ...
                'o-', 'LineWidth', 1.5, 'CapSize', 3, ...
                'Color', colors(snr_index, :), 'DisplayName', sprintf( ...
                'E_b/N_0=%.1f dB', snr_values(snr_index)));
            zero = ~positive;
            if any(zero)
                upper = [selected.coded_max_zero_event_cluster_upper95];
                valid_upper = zero & isfinite(upper) & upper > 0;
                semilogy(ax, x(valid_upper), upper(valid_upper), 'v', ...
                    'LineStyle', 'none', 'Color', colors(snr_index, :), ...
                    'HandleVisibility', 'off');
            end
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
        xlabel(ax, resource_label(resource_name));
        ylabel(ax, 'max(FPR, FNR)');
        title(ax, sprintf('%s, n=%d', ...
            function_rows(1).function_label, function_rows(1).n));
        legend(ax, 'Location', 'best');
    end
    title(layout, ['BP-LDPC fixed-sample resource-reliability tradeoff ' ...
        'with frame-cluster bootstrap 95% CIs']);
    files = export_figure_pair(fig, fullfile(output_dir, ...
        ['confirmatory_pareto_' resource_name]));
    close(fig);
end

function label = resource_label(resource_name)
    switch resource_name
        case 'channel_uses_per_bfc_decision'
            label = 'Physical channel uses per BFC decision, \nu';
        case 'parallel_bfc_rate'
            label = 'Parallel BFC rate, R_{\Sigma} per channel use';
        otherwise
            label = strrep(resource_name, '_', ' ');
    end
end
