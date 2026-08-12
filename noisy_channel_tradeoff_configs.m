function configs = noisy_channel_tradeoff_configs( ...
        sweep_type, profile, func_type, sweep_values)
%NOISY_CHANNEL_TRADEOFF_CONFIGS Build controlled E2 or LDPC-rate sweeps.
%
%   CONFIGS = NOISY_CHANNEL_TRADEOFF_CONFIGS(TYPE, PROFILE, FUNC_TYPE)
%   returns a cell array of complete noisy-channel configurations. TYPE is
%   "e2" or "ldpc_rate". The default experiment uses n=[4 6 8], AWGN,
%   and the identification function.
%
%   E2 sweep defaults:        [0.05 0.10 0.15 0.20], R_c=1/2
%   LDPC-rate sweep defaults: [1/3 2/5 1/2 3/5 2/3], E2=0.10

    if nargin < 1 || isempty(sweep_type)
        sweep_type = 'e2';
    end
    if nargin < 2 || isempty(profile)
        profile = 'local_smoke';
    end
    if nargin < 3 || isempty(func_type)
        func_type = 'id';
    end

    sweep_type = lower(strrep(char(sweep_type), '-', '_'));
    if strcmp(sweep_type, 'rate')
        sweep_type = 'ldpc_rate';
    end

    base_cfg = noisy_channel_config(profile);
    base_cfg.bfc.func_type = char(func_type);
    base_cfg.n_list = [4 8 16 32];
    base_cfg.channel_types = {'awgn'};

    switch sweep_type
        case 'e2'
            if nargin < 4 || isempty(sweep_values)
                sweep_values = [0.05 0.10 0.15 0.20];
            end
            validateattributes(sweep_values, {'numeric'}, ...
                {'vector', 'real', 'finite', 'positive', '<', 0.5});
            fixed_value = 1/2;

        case 'ldpc_rate'
            if nargin < 4 || isempty(sweep_values)
                sweep_values = [1/3 2/5 1/2 3/5 2/3];
            end
            validateattributes(sweep_values, {'numeric'}, ...
                {'vector', 'real', 'finite', 'positive', '<', 1});
            for rate = sweep_values
                dvbs2_ldpc_dimensions(rate);
            end
            fixed_value = 0.10;

        otherwise
            error('Sweep type must be "e2" or "ldpc_rate".');
    end

    sweep_values = unique(double(sweep_values(:).'), 'stable');
    aggregate_dir = fullfile('results', 'noisy_channel_tradeoffs', ...
        char(profile), char(func_type), sweep_type);
    configs = cell(1, numel(sweep_values));

    for value_index = 1:numel(sweep_values)
        cfg = base_cfg;
        sweep_value = sweep_values(value_index);

        switch sweep_type
            case 'e2'
                cfg.bfc.E2 = sweep_value;
                [cfg.ldpc.block_length, cfg.ldpc.information_length, ...
                    cfg.ldpc.rate] = dvbs2_ldpc_dimensions(fixed_value);
                result_set_name = sprintf('E2_%s_Rc_%s', ...
                    value_tag(cfg.bfc.E2), value_tag(cfg.ldpc.rate));
                display_label = sprintf('E_2=%.3g', cfg.bfc.E2);

            case 'ldpc_rate'
                cfg.bfc.E2 = fixed_value;
                [cfg.ldpc.block_length, cfg.ldpc.information_length, ...
                    cfg.ldpc.rate] = dvbs2_ldpc_dimensions(sweep_value);
                result_set_name = sprintf('E2_%s_Rc_%s', ...
                    value_tag(cfg.bfc.E2), value_tag(cfg.ldpc.rate));
                display_label = sprintf('R_c=%.4g', cfg.ldpc.rate);
        end

        cfg.experiment = struct( ...
            'type', sweep_type, ...
            'value', sweep_value, ...
            'values', sweep_values, ...
            'display_label', display_label, ...
            'aggregate_dir', aggregate_dir);
        cfg.paths.results_dir = fullfile(aggregate_dir, result_set_name);
        cfg.paths.bank_dir = fullfile(cfg.paths.results_dir, 'source_banks');
        cfg.paths.point_dir = fullfile(cfg.paths.results_dir, 'points');
        configs{value_index} = cfg;
    end
end

function tag = value_tag(value)
    tag = sprintf('%.4f', value);
    tag = regexprep(tag, '0+$', '');
    tag = regexprep(tag, '\.$', '');
    tag = strrep(tag, '-', 'm');
    tag = strrep(tag, '.', 'p');
end
