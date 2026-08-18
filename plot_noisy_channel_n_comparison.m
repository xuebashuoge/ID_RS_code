function output_files = plot_noisy_channel_n_comparison( ...
        summary, cfg, output_suffix, zero_mode, resolution)
%PLOT_NOISY_CHANNEL_N_COMPARISON Compare n on common Eb/N0 axes.
%
%   The solid curves are the end-to-end LDPC+BFC decision errors. Dashed
%   curves of the same color show the corresponding noiseless BFC floors.
%   Legends report average physical channel uses per BFC decision and the
%   parallel per-decision BFC rate.

    if nargin < 3
        output_suffix = '';
    end
    if nargin < 4
        zero_mode = 'rule_of_three';
    end
    if nargin < 5
        resolution = 160;
    end

    output_files = {};
    if isempty(summary)
        return;
    end

    channels = unique({summary.channel}, 'stable');
    markers = {'o', 's', '^', 'd', 'v', '>', '<', 'p', 'h'};
    for channel_index = 1:numel(channels)
        channel_type = channels{channel_index};
        entries = summary(strcmpi({summary.channel}, channel_type));
        [~, order] = sort([entries.n]);
        entries = entries(order);
        colors = lines(numel(entries));

        fig = figure('Visible', 'off', 'Color', 'w', ...
            'Position', [100 100 1220 470]);
        layout = tiledlayout(fig, 1, 2, ...
            'TileSpacing', 'compact', 'Padding', 'compact');

        weighted_axis = nexttile(layout);
        hold(weighted_axis, 'on');
        balanced_axis = nexttile(layout);
        hold(balanced_axis, 'on');

        for entry_index = 1:numel(entries)
            entry = entries(entry_index);
            marker = markers{mod(entry_index-1, numel(markers))+1};
            display_name = sprintf( ...
                'n=%d, \\nu=%.3g, R_{\\Sigma}=%.4f', ...
                entry.n, entry.channel_uses_per_bfc_decision, ...
                entry.parallel_bfc_rate);

            coded_weighted = prepare_zeros( ...
                entry.coded_error, entry.tuples, zero_mode);
            noiseless_weighted = prepare_zeros( ...
                entry.noiseless_error, entry.tuples, zero_mode);
            coded_balanced = prepare_zeros( ...
                entry.coded_empirical_decision_error, ...
                entry.tuples, zero_mode);
            noiseless_balanced = prepare_zeros( ...
                entry.noiseless_empirical_decision_error, ...
                entry.tuples, zero_mode);

            semilogy(weighted_axis, entry.ebno_db, coded_weighted, ...
                'Color', colors(entry_index, :), 'Marker', marker, ...
                'LineWidth', 1.8, 'DisplayName', display_name);
            semilogy(weighted_axis, entry.ebno_db, noiseless_weighted, ...
                '--', 'Color', colors(entry_index, :), 'LineWidth', 1.2, ...
                'HandleVisibility', 'off');

            semilogy(balanced_axis, entry.ebno_db, coded_balanced, ...
                'Color', colors(entry_index, :), 'Marker', marker, ...
                'LineWidth', 1.8, 'DisplayName', display_name);
            semilogy(balanced_axis, entry.ebno_db, noiseless_balanced, ...
                '--', 'Color', colors(entry_index, :), 'LineWidth', 1.2, ...
                'HandleVisibility', 'off');
        end

        semilogy(weighted_axis, NaN, NaN, 'k--', 'LineWidth', 1.2, ...
            'DisplayName', 'Noiseless BFC floor');
        semilogy(balanced_axis, NaN, NaN, 'k--', 'LineWidth', 1.2, ...
            'DisplayName', 'Noiseless BFC floor');

        style_axis(weighted_axis, 'Prior-weighted BFC error probability');
        style_axis(balanced_axis, '(FP + FN) / number of trials');
        set(weighted_axis, 'YScale', 'log');
        set(balanced_axis, 'YScale', 'log');
        title(weighted_axis, 'Uniform-message-prior decision error');
        title(balanced_axis, 'Balanced-sample decision error');
        legend(weighted_axis, 'Location', 'best');
        legend(balanced_axis, 'Location', 'best');

        function_display_name = strrep(cfg.bfc.func_type, '-', ' ');
        sgtitle(layout, sprintf('%s, %s: comparison across n', ...
            upper(channel_type), function_display_name));

        output_file = fullfile(cfg.paths.results_dir, sprintf( ...
            'noisy_channel_compare_n_%s%s.png', ...
            lower(channel_type), output_suffix));
        exportgraphics(fig, output_file, 'Resolution', resolution);
        close(fig);
        output_files{end+1} = output_file; %#ok<AGROW>
        fprintf('Saved %s\n', output_file);

        if ~all(isfield(entries, {'coded_fpr', 'coded_fnr', ...
                'coded_max_conditional_error', 'noiseless_fpr', ...
                'noiseless_fnr', 'noiseless_max_conditional_error', ...
                'actual_zero_trials', 'actual_one_trials'}))
            continue;
        end

        metric_fields = { ...
            'coded_empirical_decision_error', 'noiseless_empirical_decision_error'; ...
            'coded_fpr', 'noiseless_fpr'; ...
            'coded_fnr', 'noiseless_fnr'; ...
            'coded_max_conditional_error', 'noiseless_max_conditional_error'};
        metric_titles = {'Balanced average error', 'False-positive rate', ...
            'False-negative rate', 'max(FPR,FNR)'};
        conditional_fig = figure('Visible', 'off', 'Color', 'w', ...
            'Position', [100 100 1220 860]);
        conditional_layout = tiledlayout(conditional_fig, 2, 2, ...
            'TileSpacing', 'compact', 'Padding', 'compact');
        conditional_axes = gobjects(1, 4);
        for metric_index = 1:4
            conditional_axes(metric_index) = nexttile(conditional_layout);
            hold(conditional_axes(metric_index), 'on');
            set(conditional_axes(metric_index), 'YScale', 'log');
        end
        for entry_index = 1:numel(entries)
            entry = entries(entry_index);
            marker = markers{mod(entry_index-1, numel(markers))+1};
            curve_display_name = sprintf('n=%d, \\nu=%.3g, R_{\\Sigma}=%.4f', ...
                entry.n, entry.channel_uses_per_bfc_decision, ...
                entry.parallel_bfc_rate);
            for metric_index = 1:4
                if metric_index == 1
                    trials = entry.tuples;
                elseif metric_index == 2
                    trials = entry.actual_zero_trials;
                elseif metric_index == 3
                    trials = entry.actual_one_trials;
                else
                    trials = min(entry.actual_zero_trials, ...
                        entry.actual_one_trials);
                end
                coded_values = prepare_zeros(entry.(metric_fields{metric_index, 1}), ...
                    trials, zero_mode);
                noiseless_values = prepare_zeros( ...
                    entry.(metric_fields{metric_index, 2}), trials, zero_mode);
                ax = conditional_axes(metric_index);
                semilogy(ax, entry.ebno_db, coded_values, ...
                    'Color', colors(entry_index, :), 'Marker', marker, ...
                    'LineWidth', 1.8, 'DisplayName', curve_display_name);
                semilogy(ax, entry.ebno_db, noiseless_values, '--', ...
                    'Color', colors(entry_index, :), 'LineWidth', 1.2, ...
                    'HandleVisibility', 'off');
            end
        end
        for metric_index = 1:4
            ax = conditional_axes(metric_index);
            semilogy(ax, NaN, NaN, 'k--', 'LineWidth', 1.2, ...
                'DisplayName', 'Noiseless BFC floor');
            style_axis(ax, 'Probability');
            set(ax, 'YScale', 'log');
            title(ax, metric_titles{metric_index});
            legend(ax, 'Location', 'best');
        end
        sgtitle(conditional_layout, sprintf('%s, %s: conditional errors across n', ...
            upper(channel_type), function_display_name));
        conditional_file = fullfile(cfg.paths.results_dir, sprintf( ...
            'noisy_channel_compare_n_%s%s_conditional.png', ...
            lower(channel_type), output_suffix));
        exportgraphics(conditional_fig, conditional_file, ...
            'Resolution', resolution);
        close(conditional_fig);
        output_files{end+1} = conditional_file; %#ok<AGROW>
        fprintf('Saved %s\n', conditional_file);
    end
end

function style_axis(ax, y_label)
    grid(ax, 'on');
    xlabel(ax, 'E_b/N_0 (dB)');
    ylabel(ax, y_label);
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
