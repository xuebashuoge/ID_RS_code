function params = conference_task_params(func_type, r, K, cfg)
%CONFERENCE_TASK_PARAMS Return deterministic parameters for one task.

    params = cfg.params;
    switch lower(func_type)
        case 'id'
            % The uniform negative-message distribution is translation
            % invariant, so the all-zero target is deterministic and sufficient.
            params.target_symbols = zeros(1, K, 'uint32');
        case 'rank'
            if params.rank >= 2^(r * K)
                error('rank=%d is outside the message space for r=%d, K=%d.', ...
                    params.rank, r, K);
            end
        case 'exact-threshold'
            if params.beta > r * K
                error('beta=%d exceeds the message length m=%d.', ...
                    params.beta, r * K);
            end
        otherwise
            error('Unsupported conference task: %s.', func_type);
    end
end
