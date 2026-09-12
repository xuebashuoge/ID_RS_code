function [configs, bank_configs] = noisy_channel_confirmatory_configs(experiment)
%NOISY_CHANNEL_CONFIRMATORY_CONFIGS Fixed-sample publication simulations.
%
%   EXPERIMENT is "waterfall" or "rate_pareto". The committed adaptive
%   sweeps are treated as pilot data; these configurations predeclare the
%   frame count at every SNR and therefore support frame-cluster bootstrap
%   confidence intervals. BP results are isolated from the normalized-
%   min-sum pilot results under a new results root.

    if nargin < 1 || isempty(experiment)
        experiment = 'waterfall';
    end
    experiment = lower(strrep(char(experiment), '-', '_'));
    representatives = struct( ...
        'func_type', {'id', 'exact-threshold', 'rank'}, ...
        'n', {40, 42, 40}, ...
        'label', {'Identification', 'Exact threshold', 'Rank'});

    switch experiment
        case 'waterfall'
            rates = 1/2;
            ebno_db = 0.5:0.1:2.6;
        case 'rate_pareto'
            rates = [1/3 2/5 1/2 3/5 2/3];
            ebno_db = [1.0 1.5 2.0 2.5];
        otherwise
            error('Experiment must be "waterfall" or "rate_pareto".');
    end

    root_dir = fullfile('results', 'noisy_channel_confirmatory_bp', experiment);
    configs = cell(0, 1);
    for rep_index = 1:numel(representatives)
        rep = representatives(rep_index);
        for rate = rates
            cfg = noisy_channel_config('server_full');
            cfg.bfc.func_type = rep.func_type;
            cfg.bfc.E2 = 0.10;
            cfg.n_list = rep.n;
            cfg.channel_types = {'awgn'};
            cfg.ebno_db = ebno_db;
            [cfg.ldpc.block_length, cfg.ldpc.information_length, ...
                cfg.ldpc.rate] = dvbs2_ldpc_dimensions(rate);
            cfg.ldpc.algorithm = 'bp';
            cfg.mc.stopping_mode = 'fixed_frames';
            cfg.mc.fixed_frame_ebno_db = ebno_db;
            cfg.mc.fixed_frame_counts = fixed_frame_schedule( ...
                experiment, rep.func_type, ebno_db);
            cfg.mc.max_frames = max(cfg.mc.fixed_frame_counts);
            cfg.mc.min_frames = cfg.mc.max_frames;
            cfg.mc.max_runtime_seconds = 16*60*60;
            cfg.mc.progress_interval_seconds = 30*60;
            cfg.mc.cluster_bootstrap_replicates = 2000;
            cfg.memory.frames_per_batch = 4;
            rate_tag = value_tag(rate);
            cfg.experiment = struct( ...
                'type', experiment, ...
                'function_label', rep.label, ...
                'decoder', 'belief propagation', ...
                'display_label', sprintf('%s, n=%d, R_c=%.4g', ...
                    rep.label, rep.n, rate), ...
                'root_dir', root_dir);
            cfg.paths.results_dir = fullfile(root_dir, rep.func_type, ...
                sprintf('n_%d', rep.n), ['Rc_' rate_tag]);
            cfg.paths.point_dir = fullfile(cfg.paths.results_dir, 'points');
            cfg.paths.bank_dir = fullfile(root_dir, 'source_banks', ...
                rep.func_type, 'E2_0p1');
            configs{end+1, 1} = cfg; %#ok<AGROW>
        end
    end
    bank_configs = select_bank_configs(configs);
end

function frames = fixed_frame_schedule(experiment, func_type, ebno_db)
    %#ok<INUSD> Uniform sampling makes every operating point directly
    % comparable and avoids changes in interval width at schedule boundaries.
    frames = 2500 * ones(size(ebno_db));
end

function bank_configs = select_bank_configs(configs)
    keys = strings(0, 1);
    bank_configs = cell(0, 1);
    required_tuples = zeros(0, 1);
    for config_index = 1:numel(configs)
        cfg = configs{config_index};
        key = sprintf('%s|%.12g|%d', ...
            cfg.bfc.func_type, cfg.bfc.E2, cfg.n_list);
        d = derive_bfc_parameters(cfg, cfg.n_list);
        required = cfg.mc.max_frames * d.tuples_per_frame;
        match = find(keys == key, 1);
        if isempty(match)
            keys(end+1, 1) = key; %#ok<AGROW>
            bank_configs{end+1, 1} = cfg; %#ok<AGROW>
            required_tuples(end+1, 1) = required; %#ok<AGROW>
        elseif required > required_tuples(match)
            bank_configs{match} = cfg;
            required_tuples(match) = required;
        end
    end
end

function tag = value_tag(value)
    tag = sprintf('%.4f', value);
    tag = regexprep(tag, '0+$', '');
    tag = regexprep(tag, '\.$', '');
    tag = strrep(tag, '.', 'p');
end
