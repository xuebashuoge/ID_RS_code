function main_noisy_channel_sim(profile)
%MAIN_NOISY_CHANNEL_SIM Run a complete noisy-channel profile serially.
%
% With no input this runs only the two-frame local smoke profile. Use the
% supplied SLURM workflow for server_full rather than invoking it locally.

    if nargin < 1
        profile = 'local_smoke';
    end
    cfg = noisy_channel_config(profile);
    if ~exist(cfg.paths.results_dir, 'dir')
        mkdir(cfg.paths.results_dir);
    end
    save(fullfile(cfg.paths.results_dir, 'configuration.mat'), 'cfg');

    for n = cfg.n_list
        bank_file = noisy_channel_bank_file(cfg, n);
        bank = prepare_bfc_source_bank(cfg, n, bank_file);
        for channel_idx = 1:numel(cfg.channel_types)
            channel_type = cfg.channel_types{channel_idx};
            for ebno_db = cfg.ebno_db
                result_file = noisy_channel_result_file(cfg, n, channel_type, ebno_db);
                run_noisy_channel_point(cfg, bank, channel_type, ebno_db, result_file);
            end
        end
    end
    plot_noisy_channel_results(cfg);
end
