function outputs = plot_ldpc_awgn_calibration_results()
%PLOT_LDPC_AWGN_CALIBRATION_RESULTS Aggregate fixed-frame LDPC checks.

    cfg = ldpc_awgn_calibration_config();
    rows = struct([]);
    for rate = cfg.rates
        for algorithm_index = 1:numel(cfg.algorithms)
            algorithm = cfg.algorithms{algorithm_index};
            for ebno_db = cfg.ebno_db
                filename = ldpc_awgn_calibration_result_file( ...
                    cfg, rate, algorithm, ebno_db);
                if ~isfile(filename)
                    continue;
                end
                saved = load(filename, 'result');
                if ~saved.result.complete
                    continue;
                end
                r = saved.result;
                row = struct('rate', r.rate, ...
                    'algorithm', string(r.algorithm), ...
                    'ebno_db', r.ebno_db, 'esno_db', r.esno_db, ...
                    'frames', r.frames, 'frame_errors', r.frame_errors, ...
                    'bit_trials', r.bit_trials, 'bit_errors', r.bit_errors, ...
                    'fer', r.fer, 'ber', r.ber, ...
                    'uncoded_bpsk_ber', r.uncoded_bpsk_ber, ...
                    'mean_iterations', r.mean_iterations, ...
                    'source_file', string(filename));
                if isempty(rows)
                    rows = row;
                else
                    rows(end+1) = orderfields(row, rows); %#ok<AGROW>
                end
            end
        end
    end
    if isempty(rows)
        error('No completed LDPC calibration points were found.');
    end
    table_out = struct2table(rows);
    outputs.csv = fullfile(cfg.results_dir, 'ldpc_calibration_results.csv');
    writetable(table_out, outputs.csv);
    outputs.mat = fullfile(cfg.results_dir, 'ldpc_calibration_results.mat');
    save(outputs.mat, 'rows', 'cfg');

    fig = figure('Visible', 'off', 'Color', 'w', ...
        'Position', [100 100 1200 480]);
    layout = tiledlayout(fig, 1, 2, ...
        'TileSpacing', 'compact', 'Padding', 'compact');
    metrics = {'ber', 'fer'};
    titles = {'Information-bit BER', 'Frame error rate'};
    colors = lines(numel(cfg.rates));
    line_styles = {'-', '--'};
    markers = {'o', 's'};
    for metric_index = 1:2
        ax = nexttile(layout);
        hold(ax, 'on');
        set(ax, 'YScale', 'log');
        for algorithm_index = 1:numel(cfg.algorithms)
            algorithm = cfg.algorithms{algorithm_index};
            for rate_index = 1:numel(cfg.rates)
                selected = rows(strcmp([rows.algorithm], algorithm) & ...
                    abs([rows.rate]-cfg.rates(rate_index)) < 1e-12);
                [~, order] = sort([selected.ebno_db]);
                selected = selected(order);
                values = [selected.(metrics{metric_index})];
                trials = [selected.frames];
                if metric_index == 1
                    trials = [selected.bit_trials];
                end
                ebno = [selected.ebno_db];
                positive = values > 0;
                line_values = values;
                line_values(~positive) = NaN;
                semilogy(ax, ebno, line_values, ...
                    'Color', colors(rate_index, :), ...
                    'LineStyle', line_styles{algorithm_index}, ...
                    'Marker', markers{algorithm_index}, ...
                    'LineWidth', 1.3, 'DisplayName', sprintf( ...
                    '%s, R_c=%.3g', algorithm, cfg.rates(rate_index)));
                zero = ~positive;
                if any(zero)
                    upper = 3 ./ trials(zero);
                    semilogy(ax, ebno(zero), upper, 'v', ...
                        'LineStyle', 'none', ...
                        'Color', colors(rate_index, :), ...
                        'HandleVisibility', 'off');
                end
            end
        end
        grid(ax, 'on');
        box(ax, 'on');
        xlabel(ax, 'Payload-referenced E_b/N_0 (dB)');
        ylabel(ax, titles{metric_index});
        title(ax, titles{metric_index});
        legend(ax, 'Location', 'best', 'FontSize', 7);
    end
    title(layout, ['DVB-S2 LDPC AWGN calibration; downward triangles ' ...
        'are zero-observation upper bounds']);
    outputs.figure = export_figure_pair(fig, fullfile(cfg.results_dir, ...
        'ldpc_awgn_calibration'));
    close(fig);
end
