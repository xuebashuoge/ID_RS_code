function filename = noisy_channel_bank_file(cfg, n)
%NOISY_CHANNEL_BANK_FILE Canonical source-bank path for one n.
    filename = fullfile(cfg.paths.bank_dir, sprintf('bank_n_%d.mat', n));
end
