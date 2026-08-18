function filename = noisy_channel_result_file(cfg, n, channel_type, ebno_db)
%NOISY_CHANNEL_RESULT_FILE Canonical result path for one simulation point.
    % Keep legacy integer/one-decimal names while supporting dense grids
    % without collisions (for example 1.25 and 1.5 dB).
    tag = sprintf('%+.3f', ebno_db);
    while tag(end) == '0' && tag(end-1) ~= '.'
        tag(end) = [];
    end
    tag = strrep(tag, '+', 'p');
    tag = strrep(tag, '-', 'm');
    tag = strrep(tag, '.', 'p');
    filename = fullfile(cfg.paths.point_dir, ...
        sprintf('result_n_%d_%s_ebno_%s.mat', n, lower(channel_type), tag));
end
