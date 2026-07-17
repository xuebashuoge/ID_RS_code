function rate = rate_calculation(n, m, func_type)


    switch lower(func_type)
        case 'id'
            rate = 1/n * log2(m);
        case 'exact-threshold'
            rate = 1/n * log2(m);
        case 'at-most-threshold'
            rate = 1/n * log2(m);
        case 'bit-query'
            rate = 1/n * m;
        case 'and-subset'
            rate = 1/n * m;
        case 'rank'
            rate = 1/n * log2(m);
        otherwise
            error('Unknown boolean function type.');
    end
end