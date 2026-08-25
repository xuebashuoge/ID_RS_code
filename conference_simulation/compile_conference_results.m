function compile_conference_results()
%COMPILE_CONFERENCE_RESULTS Aggregate shards, write tables, and make figures.

    root_dir = fileparts(fileparts(mfilename('fullpath')));
    addpath(root_dir, fullfile(root_dir, 'conference_simulation'));
    cd(root_dir);
    cfg = conference_config();
    ensure_output_directories(cfg);

    summary_table = aggregate_finite_length(cfg);
    writetable(summary_table, fullfile(cfg.table_dir, ...
        'conference_finite_length_summary.csv'));
    save(fullfile(cfg.processed_dir, 'conference_finite_length_summary.mat'), ...
        'summary_table');

    n40_table = summary_table(summary_table.n == 40, :);
    writetable(n40_table, fullfile(cfg.table_dir, ...
        'conference_parameter_table_n40.csv'));

    plot_finite_length(summary_table, cfg);

    rate_file = fullfile(cfg.raw_dir, 'rate_exponent', ...
        'rate_exponent_points.csv');
    if ~isfile(rate_file)
        fprintf('Rate/exponent data are missing; generating them now.\n');
        run_rate_error_exponent();
    end
    rate_table = readtable(rate_file, 'TextType', 'string');
    plot_rate_exponent(rate_table, cfg);

    fprintf('Conference outputs written under %s.\n', cfg.processed_dir);
end

function ensure_output_directories(cfg)
    directories = {cfg.processed_dir, cfg.figure_dir, cfg.table_dir};
    for index = 1:numel(directories)
        if ~isfolder(directories{index})
            mkdir(directories{index});
        end
    end
end

function summary_table = aggregate_finite_length(cfg)
    input_dir = fullfile(cfg.raw_dir, 'finite_length');
    files = dir(fullfile(input_dir, '*.mat'));
    files = files(~contains({files.name}, '_checkpoint'));
    if isempty(files)
        error('No completed finite-length result files found in %s.', input_dir);
    end

    records = struct([]);
    for file_index = 1:numel(files)
        path = fullfile(files(file_index).folder, files(file_index).name);
        loaded = load(path, 'metadata', 'stat');
        if ~isfield(loaded, 'metadata') || ~isfield(loaded, 'stat')
            warning('Skipping non-result MAT file: %s', path);
            continue;
        end
        records(end + 1).metadata = loaded.metadata; %#ok<AGROW>
        records(end).stat = loaded.stat;
        records(end).path = path;
    end
    if isempty(records)
        error('No valid completed finite-length results were loaded.');
    end

    keys = strings(numel(records), 1);
    for index = 1:numel(records)
        keys(index) = sprintf('%s|%d', ...
            records(index).metadata.func_type, records(index).metadata.n);
    end
    unique_keys = unique(keys, 'stable');
    rows = cell(0, 20);

    adversarial = load_adversarial_status(cfg);
    for key_index = 1:numel(unique_keys)
        indices = find(keys == unique_keys(key_index));
        meta = records(indices(1)).metadata;
        seeds = zeros(numel(indices), 1);
        all_fpr = [];
        analytic_values = zeros(numel(indices), 1);
        for local_index = 1:numel(indices)
            current = records(indices(local_index));
            seeds(local_index) = current.metadata.seed;
            all_fpr = [all_fpr; current.stat.fpr_exact(:)]; %#ok<AGROW>
            analytic_values(local_index) = current.stat.average_conditional_fp;
        end
        if numel(unique(seeds)) ~= numel(seeds)
            error(['Duplicate random seeds found across shards for %s. ', ...
                'Remove or regenerate the overlapping shard before aggregation.'], ...
                unique_keys(key_index));
        end
        tolerance = 100 * eps(max(1, max(abs(analytic_values))));
        if max(analytic_values) - min(analytic_values) > tolerance
            error('Analytical averages disagree across shards for %s.', ...
                unique_keys(key_index));
        end
        q = empirical_quantile(all_fpr, [0.05, 0.50, 0.95]);
        [adv_verified, adv_fpr] = adversarial_for( ...
            adversarial, meta.func_type, meta.n);
        rows(end + 1, :) = {meta.func_type, meta.E_FP_design, meta.n, ...
            meta.r, meta.L, meta.K, meta.m, meta.S, meta.rate, ...
            meta.theorem_bound, records(indices(1)).stat.average_joint_fp, ...
            mean(analytic_values), numel(all_fpr), mean(all_fpr), ...
            q(1), q(2), q(3), max(all_fpr), adv_verified, adv_fpr}; %#ok<AGROW>
    end

    summary_table = cell2table(rows, 'VariableNames', { ...
        'func_type', 'design_E_FP', 'n', 'r', 'L', 'K', 'm', 'S', ...
        'rate', 'theorem_bound', 'proposition1_joint_average', ...
        'negative_conditional_average', 'sample_count', 'sample_mean', ...
        'q05', 'median', 'q95', 'sample_max', ...
        'adversarial_verified', 'adversarial_fpr'});
    summary_table = sortrows(summary_table, {'func_type', 'n'});
end

function adversarial = load_adversarial_status(cfg)
    files = dir(fullfile(cfg.raw_dir, 'adversarial', 'adversarial_*.mat'));
    files = files(~contains({files.name}, '_checkpoint'));
    adversarial = {};
    for index = 1:numel(files)
        loaded = load(fullfile(files(index).folder, files(index).name), 'metadata');
        if isfield(loaded, 'metadata')
            adversarial{end + 1} = loaded.metadata; %#ok<AGROW>
        end
    end
end

function [verified, fpr] = adversarial_for(adversarial, func_type, n)
    verified = false;
    fpr = NaN;
    for index = 1:numel(adversarial)
        item = adversarial{index};
        if strcmpi(item.func_type, func_type) && item.n == n
            verified = item.verified;
            if verified && isfield(item, 'observed_fpr')
                fpr = item.observed_fpr;
            end
            return;
        end
    end
end

function plot_finite_length(summary_table, cfg)
    task_titles = {'Identification', 'Rank (S=21)', ...
        'Exact threshold (\beta=2)'};
    fig = figure('Color', 'white', 'Position', [100, 100, 1500, 440]);
    layout = tiledlayout(fig, 1, 3, 'TileSpacing', 'compact', ...
        'Padding', 'compact');

    for task_index = 1:numel(cfg.tasks)
        ax = nexttile(layout);
        task = cfg.tasks{task_index};
        data = summary_table(strcmpi(summary_table.func_type, task), :);
        data = sortrows(data, 'n');
        if isempty(data)
            title(ax, [task_titles{task_index}, ' (missing)']);
            continue;
        end
        x = data.n;
        zero_floor = 0.5 ./ data.L;
        q05 = max(data.q05, zero_floor);
        q95 = max(data.q95, zero_floor);
        median_values = max(data.median, zero_floor);
        maximum_values = max(data.sample_max, zero_floor);

        fill(ax, [x; flipud(x)], [q05; flipud(q95)], ...
            [0.75, 0.85, 1.0], 'EdgeColor', 'none', ...
            'FaceAlpha', 0.55, 'DisplayName', '5--95%');
        hold(ax, 'on');
        semilogy(ax, x, median_values, 'o-', 'LineWidth', 1.8, ...
            'Color', [0.00, 0.35, 0.75], 'DisplayName', 'Median');
        semilogy(ax, x, maximum_values, '^-', 'LineWidth', 1.3, ...
            'Color', [0.90, 0.45, 0.05], 'DisplayName', 'Sample maximum');
        semilogy(ax, x, data.negative_conditional_average, '-.', ...
            'LineWidth', 1.8, 'Color', [0.10, 0.55, 0.20], ...
            'DisplayName', 'Proposition 1 mean');
        semilogy(ax, x, data.theorem_bound, '--', 'LineWidth', 1.8, ...
            'Color', [0.80, 0.10, 0.10], 'DisplayName', 'Theorem bound');
        verified = data.adversarial_verified;
        if any(verified)
            semilogy(ax, x(verified), data.adversarial_fpr(verified), ...
                'kp', 'MarkerSize', 10, 'MarkerFaceColor', 'k', ...
                'DisplayName', 'Constructed worst case');
        end
        set(ax, 'YScale', 'log');
        grid(ax, 'on');
        xlabel(ax, 'Channel use n');
        if task_index == 1
            ylabel(ax, 'False-positive probability');
            legend(ax, 'Location', 'southwest', 'FontSize', 8);
        end
        title(ax, task_titles{task_index});
    end
    title(layout, sprintf(['Finite-length typical and worst-case performance ', ...
        '(E_{FP}=%.2f)'], cfg.E_FP));
    save_figure_300dpi(fig, fullfile(cfg.figure_dir, ...
        'figure1_finite_length_typical_worst_case'));
    close(fig);
end

function plot_rate_exponent(rate_table, cfg)
    task_titles = {'Identification', 'Rank (S=21)', ...
        'Exact threshold (\beta=2)'};
    colors = lines(numel(cfg.rate_exponents));
    fig = figure('Color', 'white', 'Position', [100, 100, 1500, 440]);
    layout = tiledlayout(fig, 1, 3, 'TileSpacing', 'compact', ...
        'Padding', 'compact');

    for task_index = 1:numel(cfg.tasks)
        ax = nexttile(layout);
        task = cfg.tasks{task_index};
        data = rate_table(strcmpi(rate_table.func_type, task), :);
        beta = 0;
        if strcmpi(task, 'exact-threshold')
            beta = cfg.params.beta;
        end
        hold(ax, 'on');
        for E_index = 1:numel(cfg.rate_exponents)
            design_E = cfg.rate_exponents(E_index);
            points = data(abs(data.design_E_FP - design_E) < 1e-12, :);
            points = sortrows(points, 'n');
            plot(ax, points.rate, points.realized_exponent, 'o-', ...
                'Color', colors(E_index, :), 'LineWidth', 1.3, ...
                'MarkerSize', 4, ...
                'DisplayName', sprintf('Design E=%.2f', design_E));
        end
        x_limit = [max(0, min(data.rate) - 0.02), max(data.rate) + 0.02];
        x_line = linspace(x_limit(1), x_limit(2), 200);
        y_line = 0.5 - (beta + 1) * x_line;
        plot(ax, x_line, y_line, 'k--', 'LineWidth', 1.8, ...
            'DisplayName', sprintf('E+%dR=1/2', beta + 1));
        xlim(ax, x_limit);
        ylim(ax, [0, max(0.25, max(data.realized_exponent) * 1.08)]);
        grid(ax, 'on');
        xlabel(ax, 'R = log_2(m)/n');
        if task_index == 1
            ylabel(ax, 'Realized exponent');
            legend(ax, 'Location', 'best', 'FontSize', 8);
        end
        title(ax, task_titles{task_index});
    end
    title(layout, 'Finite-length rate--false-positive-exponent diagram');
    save_figure_300dpi(fig, fullfile(cfg.figure_dir, ...
        'figure2_rate_error_exponent'));
    close(fig);
end
