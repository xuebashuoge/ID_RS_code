function summary = replot_noisy_channel_drop_zeros(profile, func_type)
%REPLOT_NOISY_CHANNEL_DROP_ZEROS Replot saved results without artificial floors.
%
%   REPLOT_NOISY_CHANNEL_DROP_ZEROS(PROFILE, FUNC_TYPE) replots the selected
%   saved Boolean-function family. Its configuration and values of n come
%   from the saved results, so noisy_channel_config does not need to match the
%   saved run. Metrics whose measured error rate is exactly zero are converted
%   to NaN before plotting, so semilogy omits those points and breaks the
%   connecting line. Existing simulation point files are not changed.
%
%   Example:
%     replot_noisy_channel_drop_zeros('server_full', 'exact-threshold')

    if nargin < 1
        profile = 'server_full';
    end
    if nargin < 2
        error(['Specify the saved function type to replot, for example: ' ...
            'replot_noisy_channel_drop_zeros(''server_full'', ''exact-threshold'').']);
    end
    func_type = char(func_type);

    profile_dir = fullfile('results', 'noisy_channel', profile);
    if ~exist(profile_dir, 'dir')
        error('Profile results directory does not exist: %s', profile_dir);
    end

    summary_files = dir(fullfile(profile_dir, '**', 'summary_noisy_channel.mat'));
    if isempty(summary_files)
        error('No saved noisy-channel summaries were found under %s.', profile_dir);
    end

    [~, order] = sort({summary_files.folder});
    summary_files = summary_files(order);
    summary = struct([]);
    available_func_types = {};

    for result_set_idx = 1:numel(summary_files)
        summary_file = fullfile(summary_files(result_set_idx).folder, ...
            summary_files(result_set_idx).name);
        saved = load(summary_file, 'cfg');
        if ~isfield(saved, 'cfg') || ~isfield(saved.cfg, 'bfc') || ...
                ~isfield(saved.cfg.bfc, 'func_type')
            warning('Skipping summary without saved cfg metadata: %s', summary_file);
            continue;
        end

        cfg = saved.cfg;
        available_func_types{end+1} = cfg.bfc.func_type; %#ok<AGROW>
        if ~strcmpi(cfg.bfc.func_type, func_type)
            continue;
        end

        cfg.profile = char(profile);
        cfg.paths.results_dir = summary_files(result_set_idx).folder;
        cfg.paths.point_dir = fullfile(cfg.paths.results_dir, 'points');
        cfg.paths.bank_dir = fullfile(cfg.paths.results_dir, 'source_banks');
        cfg.n_list = saved_n_list(cfg.paths.results_dir, cfg.paths.point_dir);

        fprintf('Replotting saved %s results with n = %s\n', ...
            cfg.bfc.func_type, mat2str(cfg.n_list));
        result_set_summary = replot_result_set(cfg);
        if isempty(summary)
            summary = result_set_summary;
        elseif ~isempty(result_set_summary)
            summary = [summary, orderfields(result_set_summary, summary)]; %#ok<AGROW>
        end
    end

    if isempty(summary)
        available = strjoin(unique(available_func_types), ', ');
        error('No saved results for func_type "%s" under %s. Available: %s.', ...
            func_type, profile_dir, available);
    end
end

function summary = replot_result_set(cfg)
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
            coded_empirical = arrayfun(@(x) x.result.metrics.coded.balanced_error, points);
            uncoded_empirical = arrayfun(@(x) x.result.metrics.uncoded.balanced_error, points);
            noiseless_empirical = arrayfun(@(x) x.result.metrics.noiseless.balanced_error, points);
            ldpc_fer = arrayfun(@(x) x.result.metrics.ldpc_fer, points);
            ldpc_ber = arrayfun(@(x) x.result.metrics.ldpc_payload_ber, points);
            coded_tuple = arrayfun(@(x) x.result.metrics.coded_tuple_error_rate, points);
            tuples = arrayfun(@(x) x.result.tuples, points);
            frames = arrayfun(@(x) x.result.frames, points);
            rates = noisy_channel_rate_metadata(points(1).result);

            % NaN values are not drawn by semilogy. This preserves the raw
            % zero measurement without inventing a positive plotting value.
            coded_plot = drop_zero_rates(coded);
            uncoded_plot = drop_zero_rates(uncoded);
            noiseless_plot = drop_zero_rates(noiseless);
            coded_empirical_plot = drop_zero_rates(coded_empirical);
            uncoded_empirical_plot = drop_zero_rates(uncoded_empirical);
            noiseless_empirical_plot = drop_zero_rates(noiseless_empirical);
            fer_plot = drop_zero_rates(ldpc_fer);
            ber_plot = drop_zero_rates(ldpc_ber);
            tuple_plot = drop_zero_rates(coded_tuple);

            fig = figure('Visible', 'off', 'Color', 'w', ...
                'Position', [100 100 1550 440]);
            layout = tiledlayout(fig, 1, 3, ...
                'TileSpacing', 'compact', 'Padding', 'compact');

            nexttile(layout);
            semilogy(ebno, coded_plot, 'bo-', 'LineWidth', 1.8, ...
                'DisplayName', 'LDPC + BFC');
            hold on;
            semilogy(ebno, uncoded_plot, 'rx-', 'LineWidth', 1.6, ...
                'DisplayName', 'Uncoded BPSK + BFC');
            semilogy(ebno, noiseless_plot, 'k--', 'LineWidth', 1.5, ...
                'DisplayName', 'Noiseless BFC');
            grid on;
            xlabel('E_b/N_0 (dB)');
            ylabel('Prior-weighted BFC error probability');
            title(sprintf('n=%d, %s', n, upper(channel_type)));
            legend('Location', 'best');

            nexttile(layout);
            semilogy(ebno, coded_empirical_plot, 'bo-', 'LineWidth', 1.8, ...
                'DisplayName', 'LDPC + ID');
            hold on;
            semilogy(ebno, uncoded_empirical_plot, 'rx-', 'LineWidth', 1.6, ...
                'DisplayName', 'Uncoded BPSK + ID');
            semilogy(ebno, noiseless_empirical_plot, 'k--', 'LineWidth', 1.5, ...
                'DisplayName', 'Noiseless ID');
            grid on;
            xlabel('E_b/N_0 (dB)');
            ylabel('(FP + FN) / number of trials');
            display_name = strrep(cfg.bfc.func_type, '-', ' ');
            title(sprintf('Empirical %s decision error', display_name));
            legend('Location', 'best');

            nexttile(layout);
            semilogy(ebno, fer_plot, 'ms-', 'LineWidth', 1.8, ...
                'DisplayName', 'LDPC FER');
            hold on;
            semilogy(ebno, ber_plot, 'gd-', 'LineWidth', 1.6, ...
                'DisplayName', 'LDPC payload BER');
            semilogy(ebno, tuple_plot, 'c^-', 'LineWidth', 1.6, ...
                'DisplayName', 'Coded tuple error');
            grid on;
            xlabel('E_b/N_0 (dB)');
            ylabel('Error rate');
            title(sprintf(['R_{payload}=%.4f, \\nu=%.3g, ' ...
                'R_{\\Sigma}=%.4f; zeros omitted'], ...
                rates.ldpc_payload_rate, ...
                rates.channel_uses_per_bfc_decision, ...
                rates.parallel_bfc_rate));
            legend('Location', 'best');

            output_png = fullfile(cfg.paths.results_dir, sprintf( ...
                'noisy_channel_n_%d_%s_drop_zeros.png', ...
                n, lower(channel_type)));
            exportgraphics(fig, output_png, 'Resolution', 300);
            close(fig);
            fprintf('Saved %s\n', output_png);

            entry = struct( ...
                'n', n, ...
                'channel', lower(channel_type), ...
                'function_type', cfg.bfc.func_type, ...
                'ebno_db', ebno, ...
                'coded_error', coded, ...
                'uncoded_error', uncoded, ...
                'noiseless_error', noiseless, ...
                'coded_empirical_decision_error', coded_empirical, ...
                'uncoded_empirical_decision_error', uncoded_empirical, ...
                'noiseless_empirical_decision_error', noiseless_empirical, ...
                'ldpc_fer', ldpc_fer, ...
                'ldpc_payload_ber', ldpc_ber, ...
                'coded_tuple_error', coded_tuple, ...
                'tuples', tuples, ...
                'frames', frames, ...
                'ldpc_code_rate', rates.ldpc_code_rate, ...
                'ldpc_payload_rate', rates.ldpc_payload_rate, ...
                'noiseless_bfc_rate', rates.noiseless_bfc_rate, ...
                'parallel_bfc_rate', rates.parallel_bfc_rate, ...
                'channel_uses_per_bfc_decision', ...
                    rates.channel_uses_per_bfc_decision);
            if isempty(summary)
                summary = entry;
            else
                summary(end+1) = orderfields(entry, summary); %#ok<AGROW>
            end
        end
    end

    save(fullfile(cfg.paths.results_dir, ...
        'summary_noisy_channel_drop_zeros.mat'), 'summary', 'cfg');
    plot_noisy_channel_n_comparison( ...
        summary, cfg, '_drop_zeros', 'omit', 300);
end

function values = drop_zero_rates(values)
    values(values <= 0) = NaN;
end

function n_list = saved_n_list(results_dir, point_dir)
    summary_file = fullfile(results_dir, 'summary_noisy_channel.mat');
    if isfile(summary_file)
        saved = load(summary_file, 'summary');
        if isfield(saved, 'summary') && ~isempty(saved.summary) && ...
                isfield(saved.summary, 'n')
            n_list = unique(double([saved.summary.n]));
            if all(isfinite(n_list))
                return;
            end
        end
        warning('Saved summary has no valid n values; scanning point results: %s', ...
            summary_file);
    end

    if ~exist(point_dir, 'dir')
        error('Point-results directory does not exist: %s', point_dir);
    end

    files = dir(fullfile(point_dir, 'result_n_*.mat'));
    n_values = zeros(1, numel(files));
    found = false(1, numel(files));

    for file_idx = 1:numel(files)
        filename = fullfile(files(file_idx).folder, files(file_idx).name);
        saved = load(filename, 'result');
        if ~isfield(saved, 'result') || ...
                ~isfield(saved.result, 'scenario') || ...
                ~isfield(saved.result.scenario, 'n')
            warning('Skipping result without result.scenario.n: %s', filename);
            continue;
        end

        n = saved.result.scenario.n;
        if ~isnumeric(n) || ~isscalar(n) || ~isfinite(n)
            warning('Skipping result with invalid result.scenario.n: %s', filename);
            continue;
        end

        n_values(file_idx) = double(n);
        found(file_idx) = true;
    end

    n_list = unique(n_values(found));
    if isempty(n_list)
        error('No saved results with a valid result.scenario.n were found in %s.', ...
            point_dir);
    end
end
