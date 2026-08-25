function S = conference_support_size(m, func_type, params)
%CONFERENCE_SUPPORT_SIZE Exact finite-length support size for paper tasks.

    switch lower(func_type)
        case 'id'
            S = 1;
        case 'rank'
            S = params.rank + 1;
        case 'exact-threshold'
            beta = params.beta;
            if beta < 0 || beta > m
                S = 0;
            else
                beta = min(beta, m - beta);
                S = 1;
                for j = 1:beta
                    S = S * (m - beta + j) / j;
                end
                S = round(S);
            end
        otherwise
            error('Unsupported conference task: %s.', func_type);
    end
end
