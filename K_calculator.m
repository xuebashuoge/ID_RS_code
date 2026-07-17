function K = K_calculator(n, E2, params, func_type)
    % K_calculator calculates the number of codewords K based on the boolean function type and parameters.
    % id: S = 1
    % exact-threshold: S = m^beta/beta!
    % at-most-threshold: S = (e/beta)^beta * m^beta
    % bit-query: S = 2^(m-1)
    % and-subset: S = 2^(m-|S_k|)
    % rank: S = rank+1

    base_term = 2^(n*(0.5-E2));
    switch lower(func_type)
        case 'id'
            K = floor(base_term);
        case 'exact-threshold'
            beta = params.beta;
            K = floor((factorial(beta) * (2/n)^beta * base_term)^(1/(beta+1)));
        case 'at-most-threshold'
            beta = params.beta;
            K = floor(((beta/exp(1))^beta * (2/n)^beta * base_term)^(1/(beta+1)));
        case 'bit-query'
            K = floor(2/(n*log(2)) * lambertw(n*log(2)*base_term));
        case 'and-subset'
            k = length(params.S_k);
            K = floor(2/(n*log(2)) * lambertw(n*log(2)*base_term*2^(k-1)));
        case 'rank'
            rank = params.rank;
            K = floor(base_term/(rank+1));
        otherwise
            error('Unknown boolean function type.');
    end
end