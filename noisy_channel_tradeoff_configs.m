function configs = noisy_channel_tradeoff_configs( ...
        sweep_type, profile, func_type, sweep_values)
%NOISY_CHANNEL_TRADEOFF_CONFIGS Build controlled E2 or LDPC-rate sweeps.
%
%   CONFIGS = NOISY_CHANNEL_TRADEOFF_CONFIGS(TYPE, PROFILE, FUNC_TYPE)
%   returns a cell array of complete noisy-channel configurations. TYPE is
%   "e2" or "ldpc_rate". Function-specific default n grids contain only
%   nontrivial K>1 points and reuse the original server banks. Set
%   BFC_N_LIST to a colon-separated list to override the default.
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
    base_cfg.n_list = getenv_n_list( ...
        'BFC_N_LIST', default_n_list_for_function(func_type));
    base_cfg.channel_types = {'awgn'};

    switch sweep_type
        case 'e2'
            if nargin < 4 || isempty(sweep_values)
                sweep_values = [0.05 0.10 0.15 0.20];
            end
            validateattributes(sweep_values, {'numeric'}, ...
                {'vector', 'real', 'finite', 'positive', '<', 0.5});
            fixed_value = 1/2;
            % Resolve the rate-1/2 waterfall without spending jobs on the
            % already-flat 4--10 dB region.
            base_cfg.ebno_db = 0:0.25:3;

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
            % The lowest DVB-S2 rates have a later FER waterfall.
            base_cfg.ebno_db = 0:0.25:5;

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

    validate_common_nontrivial_n(configs);
end

function values = default_n_list_for_function(func_type)
    switch lower(char(func_type))
        case 'id'
            % Common to the already-generated E2 and LDPC-rate banks.
            values = [4 16];
        case 'exact-threshold'
            % At beta=2 these remain nontrivial for every default E2.
            values = [36 42];
        case 'rank'
            % n=16 gives K=1 at E2=0.2 for the default rank=20.
            values = [24 32 40];
        otherwise
            values = [4 8 16 32];
    end
end

function validate_common_nontrivial_n(configs)
    reference_n = double(configs{1}.n_list(:).');
    invalid = strings(0, 1);
    for config_index = 1:numel(configs)
        cfg = configs{config_index};
        if ~isequal(double(cfg.n_list(:).'), reference_n)
            error('Every sweep setting must use the same n grid.');
        end
        for n = reference_n
            K = K_calculator(n, cfg.bfc.E2, ...
                cfg.bfc.params, cfg.bfc.func_type);
            if K <= 1
                invalid(end+1) = sprintf('n=%d at %s gives K=%d', ...
                    n, cfg.experiment.display_label, K); %#ok<AGROW>
            end
        end
    end
    if ~isempty(invalid)
        error(['All sweep points must have nontrivial K>1. Revise ' ...
            'BFC_N_LIST. Invalid points: %s'], strjoin(invalid, '; '));
    end
end

function values = getenv_n_list(name, default_values)
    text = getenv(name);
    if isempty(text)
        values = default_values;
        return;
    end

    tokens = strsplit(text, ':');
    values = str2double(tokens);
    if isempty(values) || any(~isfinite(values)) || ...
            any(values < 2) || any(mod(values, 2) ~= 0)
        error('%s must be a colon-separated list of positive even integers.', name);
    end
end

function tag = value_tag(value)
    tag = sprintf('%.4f', value);
    tag = regexprep(tag, '0+$', '');
    tag = regexprep(tag, '\.$', '');
    tag = strrep(tag, '-', 'm');
    tag = strrep(tag, '.', 'p');
end
