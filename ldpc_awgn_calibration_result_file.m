function filename = ldpc_awgn_calibration_result_file( ...
        cfg, rate, algorithm, ebno_db)
%LDPC_AWGN_CALIBRATION_RESULT_FILE Canonical calibration result path.

    rate_tag = value_tag(rate);
    snr_tag = value_tag(ebno_db);
    algorithm_tag = strrep(algorithm, '-', '_');
    filename = fullfile(cfg.point_dir, sprintf( ...
        'ldpc_%s_Rc_%s_ebno_%s.mat', ...
        algorithm_tag, rate_tag, snr_tag));
end

function tag = value_tag(value)
    tag = sprintf('%+.3f', value);
    while tag(end) == '0' && tag(end-1) ~= '.'
        tag(end) = [];
    end
    tag = strrep(tag, '+', 'p');
    tag = strrep(tag, '-', 'm');
    tag = strrep(tag, '.', 'p');
end
