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
        title(weighted_axis, 'Uniform-message-prior decision error');
        title(balanced_axis, 'Balanced-sample decision error');
        legend(weighted_axis, 'Location', 'best');
        legend(balanced_axis, 'Location', 'best');

        display_name = strrep(cfg.bfc.func_type, '-', ' ');
        sgtitle(layout, sprintf('%s, %s: comparison across n', ...
            upper(channel_type), display_name));

        output_file = fullfile(cfg.paths.results_dir, sprintf( ...
            'noisy_channel_compare_n_%s%s.png', ...
            lower(channel_type), output_suffix));
        exportgraphics(fig, output_file, 'Resolution', resolution);
        close(fig);
        output_files{end+1} = output_file; %#ok<AGROW>
        fprintf('Saved %s\n', output_file);
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
            values(zero_mask) = 3 ./ max(1, trials(zero_mask));
        otherwise
            error('Unknown zero plotting mode "%s".', zero_mode);
    end
end
