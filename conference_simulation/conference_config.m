function cfg = conference_config()
%CONFERENCE_CONFIG Canonical configuration for the Section 3 experiments.

    cfg.tasks = {'id', 'rank', 'exact-threshold'};
    cfg.n_values = 24:2:40;
    cfg.E_FP = 0.10;
    cfg.rate_exponents = [0.05, 0.10, 0.15, 0.20];
    cfg.rate_n_values = 24:2:80;

    cfg.params.beta = 2;
    cfg.params.rank = 20;

    cfg.num_negative_messages = 2000;
    cfg.position_chunk_size = 512;
    cfg.checkpoint_every_chunks = 20;
    cfg.seed_base = 20260825;
    cfg.figure_dpi = 300;

    cfg.raw_dir = fullfile('conference_results', 'raw');
    cfg.processed_dir = fullfile('conference_results', 'processed');
    cfg.figure_dir = fullfile(cfg.processed_dir, 'figures');
    cfg.table_dir = fullfile(cfg.processed_dir, 'tables');
end
