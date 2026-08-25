function run_rate_error_exponent()
%RUN_RATE_ERROR_EXPONENT Generate exact finite-n rate/exponent points.

    root_dir = fileparts(fileparts(mfilename('fullpath')));
    addpath(root_dir, fullfile(root_dir, 'conference_simulation'));
    cd(root_dir);
    cfg = conference_config();

    rows = cell(0, 10);
    for task_index = 1:numel(cfg.tasks)
        func_type = cfg.tasks{task_index};
        for E_index = 1:numel(cfg.rate_exponents)
            design_E = cfg.rate_exponents(E_index);
            for n = cfg.rate_n_values
                r = n / 2;
                L = 2^r;
                K = K_calculator(n, design_E, cfg.params, func_type);
                % K=1 has zero false-positive probability and hence an
                % infinite exponent; omit that degenerate finite-n point.
                if K <= 1
                    continue;
                end
                m = r * K;
                S = conference_support_size(m, func_type, cfg.params);
                exact_bound = min(1, S * (K - 1) / L);
                if exact_bound == 0
                    realized_exponent = Inf;
                else
                    realized_exponent = -log2(exact_bound) / n;
                end
                rate = log2(m) / n;
                rows(end + 1, :) = {func_type, design_E, n, r, L, K, ...
                    m, S, rate, realized_exponent}; %#ok<AGROW>
            end
        end
    end

    rate_table = cell2table(rows, 'VariableNames', { ...
        'func_type', 'design_E_FP', 'n', 'r', 'L', 'K', 'm', 'S', ...
        'rate', 'realized_exponent'});
    output_dir = fullfile(cfg.raw_dir, 'rate_exponent');
    if ~isfolder(output_dir)
        mkdir(output_dir);
    end
    writetable(rate_table, fullfile(output_dir, 'rate_exponent_points.csv'));
    save(fullfile(output_dir, 'rate_exponent_points.mat'), 'rate_table');
    fprintf('Saved %d exact rate/exponent points in %s.\n', ...
        height(rate_table), output_dir);
end
