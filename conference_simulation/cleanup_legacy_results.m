function legacy_table = cleanup_legacy_results(source_root, output_dir)
%CLEANUP_LEGACY_RESULTS Normalize legacy per-n MAT files without moving them.
% Run this on each legacy branch/worktree. The CSV is a portable inventory
% that can then be compared with the new conference results.

    root_dir = fileparts(fileparts(mfilename('fullpath')));
    addpath(root_dir, fullfile(root_dir, 'conference_simulation'));
    if nargin < 1 || isempty(source_root)
        source_root = root_dir;
    end
    if nargin < 2 || isempty(output_dir)
        output_dir = fullfile(root_dir, 'conference_results', ...
            'processed', 'legacy');
    end
    cfg = conference_config();
    if ~isfolder(output_dir)
        mkdir(output_dir);
    end

    files = [ ...
        dir(fullfile(source_root, '**', 'result_n_*.mat')); ...
        dir(fullfile(source_root, '**', 'fixed_msg_result_n_*.mat'))];
    rows = cell(0, 15);

    for index = 1:numel(files)
        path = fullfile(files(index).folder, files(index).name);
        loaded = load(path);
        if ~all(isfield(loaded, {'n', 'r', 'L', 'K', 'm'}))
            warning('Skipping legacy file missing core parameters: %s', path);
            continue;
        end
        task = task_from_path(path);
        if isempty(task)
            warning('Could not infer task from path; skipping: %s', path);
            continue;
        end
        params = cfg.params;
        S = conference_support_size(loaded.m, task, params);
        if isfield(loaded, 'S')
            S = loaded.S;
        end
        rate = log2(loaded.m) / loaded.n;
        if isfield(loaded, 'rate')
            rate = loaded.rate;
        end
        bound = min(1, S * (loaded.K - 1) / loaded.L);
        analytic_joint = NaN;
        if isfield(loaded, 'expected_FP')
            analytic_joint = loaded.expected_FP;
        end

        exact_fixed_fpr = NaN;
        position_mc_fpr = NaN;
        uniform_joint_mc = NaN;
        if isfield(loaded, 'stat_single')
            source_kind = 'single_fixed_message';
            exact_fixed_fpr = loaded.stat_single.fp_prob_exact;
            position_mc_fpr = loaded.stat_single.fp_prob_mc;
            if isfield(loaded, 'upper_bound')
                bound = loaded.upper_bound;
            end
        elseif isfield(loaded, 'stat')
            source_kind = 'uniform_message_position_mc';
            uniform_joint_mc = loaded.stat.fp_prob;
        else
            continue;
        end

        rows(end + 1, :) = {path, source_kind, task, loaded.n, loaded.r, ...
            loaded.L, loaded.K, loaded.m, S, rate, exact_fixed_fpr, ...
            position_mc_fpr, uniform_joint_mc, analytic_joint, bound}; %#ok<AGROW>
    end

    legacy_table = cell2table(rows, 'VariableNames', { ...
        'source_file', 'source_kind', 'func_type', 'n', 'r', 'L', 'K', ...
        'm', 'S', 'rate', 'exact_fixed_fpr', 'position_mc_fpr', ...
        'uniform_joint_mc', 'proposition1_joint_average', 'theorem_bound'});
    if ~isempty(legacy_table)
        legacy_table = sortrows(legacy_table, ...
            {'func_type', 'source_kind', 'n'});
    end
    writetable(legacy_table, fullfile(output_dir, ...
        'legacy_results_inventory.csv'));
    save(fullfile(output_dir, 'legacy_results_inventory.mat'), 'legacy_table');
    fprintf('Normalized %d legacy result files into %s.\n', ...
        height(legacy_table), output_dir);
end

function task = task_from_path(path)
    lower_path = lower(path);
    if contains(lower_path, 'exact-threshold')
        task = 'exact-threshold';
    elseif contains(lower_path, 'rank')
        task = 'rank';
    elseif contains(lower_path, [filesep, 'id_']) || ...
            contains(lower_path, 'fixed_msg_id_')
        task = 'id';
    else
        task = '';
    end
end
