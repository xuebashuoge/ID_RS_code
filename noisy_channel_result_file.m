function filename = noisy_channel_result_file(cfg, n, channel_type, ebno_db)
%NOISY_CHANNEL_RESULT_FILE Canonical result path for one simulation point.
    tag = sprintf('%+.1f', ebno_db);
    tag = strrep(tag, '+', 'p');
    tag = strrep(tag, '-', 'm');
    tag = strrep(tag, '.', 'p');
    filename = fullfile(cfg.paths.point_dir, ...
        sprintf('result_n_%d_%s_ebno_%s.mat', n, lower(channel_type), tag));
end
