function summary = plot_noisy_channel_results(cfg)
%PLOT_NOISY_CHANNEL_RESULTS Aggregate point files and produce comparison plots.

    if ~exist(cfg.paths.results_dir, 'dir')
        error('Results directory does not exist: %s', cfg.paths.results_dir);
    end
    summary = struct([]);

    for n = cfg.n_list
        for channel_idx = 1:numel(cfg.channel_types)
            channel_type = cfg.channel_types{channel_idx};
            points = struct([]);
            for ebno_db = cfg.ebno_db
                filename = noisy_channel_result_file(cfg, n, channel_type, ebno_db);
                if ~isfile(filename)
                    continue;
                end
                loaded = load(filename, 'result');
                if loaded.result.complete
                    points(end+1).result = loaded.result; %#ok<AGROW>
                end
            end
            if isempty(points)
                continue;
            end

            ebno = arrayfun(@(x) x.result.scenario.ebno_db, points);
            [ebno, order] = sort(ebno);
            points = points(order);
            coded = arrayfun(@(x) x.result.metrics.coded.weighted_error, points);
            uncoded = arrayfun(@(x) x.result.metrics.uncoded.weighted_error, points);
            noiseless = arrayfun(@(x) x.result.metrics.noiseless.weighted_error, points);
            ldpc_fer = arrayfun(@(x) x.result.metrics.ldpc_fer, points);
            ldpc_ber = arrayfun(@(x) x.result.metrics.ldpc_payload_ber, points);
            coded_tuple = arrayfun(@(x) x.result.metrics.coded_tuple_error_rate, points);
            tuples = arrayfun(@(x) x.result.tuples, points);
            frames = arrayfun(@(x) x.result.frames, points);

            coded_plot = zero_safe(coded, tuples);
            uncoded_plot = zero_safe(uncoded, tuples);
            noiseless_plot = zero_safe(noiseless, tuples);
            fer_plot = zero_safe(ldpc_fer, frames);
            ber_plot = zero_safe(ldpc_ber, tuples*n);
            tuple_plot = zero_safe(coded_tuple, tuples);

            fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 1050 440]);
            layout = tiledlayout(fig, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');

            nexttile(layout);
            semilogy(ebno, coded_plot, 'bo-', 'LineWidth', 1.8, 'DisplayName', 'LDPC + BFC');
            hold on;
            semilogy(ebno, uncoded_plot, 'rx-', 'LineWidth', 1.6, 'DisplayName', 'Uncoded BPSK + BFC');
            semilogy(ebno, noiseless_plot, 'k--', 'LineWidth', 1.5, 'DisplayName', 'Noiseless BFC');
            grid on;
            xlabel('E_b/N_0 (dB)');
            ylabel('Prior-weighted BFC error probability');
            title(sprintf('n=%d, %s', n, upper(channel_type)));
            legend('Location', 'best');

            nexttile(layout);
            semilogy(ebno, fer_plot, 'ms-', 'LineWidth', 1.8, 'DisplayName', 'LDPC FER');
            hold on;
            semilogy(ebno, ber_plot, 'gd-', 'LineWidth', 1.6, 'DisplayName', 'LDPC payload BER');
            semilogy(ebno, tuple_plot, 'c^-', 'LineWidth', 1.6, 'DisplayName', 'Coded tuple error');
            grid on;
            xlabel('E_b/N_0 (dB)');
            ylabel('Error rate');
            title(sprintf('R_{eff}=%.5f', points(1).result.derived.effective_rate));
            legend('Location', 'best');

            output_png = fullfile(cfg.paths.results_dir, ...
                sprintf('noisy_channel_n_%d_%s.png', n, lower(channel_type)));
            exportgraphics(fig, output_png, 'Resolution', 160);
            close(fig);

            entry = struct( ...
                'n', n, ...
                'channel', lower(channel_type), ...
                'ebno_db', ebno, ...
                'coded_error', coded, ...
                'uncoded_error', uncoded, ...
                'noiseless_error', noiseless, ...
                'ldpc_fer', ldpc_fer, ...
                'ldpc_payload_ber', ldpc_ber, ...
                'coded_tuple_error', coded_tuple);
            if isempty(summary)
                summary = entry;
            else
                summary(end+1) = orderfields(entry, summary); %#ok<AGROW>
            end
        end
    end

    save(fullfile(cfg.paths.results_dir, 'summary_noisy_channel.mat'), 'summary', 'cfg');
end

function values = zero_safe(values, trials)
    zero_mask = values <= 0;
    values(zero_mask) = 3 ./ max(1, trials(zero_mask));
end
