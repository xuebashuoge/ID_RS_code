function [S, valid_symbols] = build_conference_support(r, K, func_type, params)
%BUILD_CONFERENCE_SUPPORT Build the positive support directly in GF symbols.
% This avoids the large and numerically fragile intermediate bit matrices in
% the legacy implementation.

    q = 2^r;
    m = r * K;

    switch lower(func_type)
        case 'id'
            valid_symbols = uint32(params.target_symbols);
            if ~isequal(size(valid_symbols), [1, K])
                error('params.target_symbols must have size 1-by-K.');
            end
            S = 1;

        case 'rank'
            S = params.rank + 1;
            valid_symbols = zeros(S, K, 'uint32');
            remaining = (0:params.rank).';
            for k = K:-1:1
                valid_symbols(:, k) = uint32(mod(remaining, q));
                remaining = floor(remaining / q);
            end
            if any(remaining ~= 0)
                error('Rank support cannot be represented with K symbols.');
            end

        case 'exact-threshold'
            beta = params.beta;
            if beta == 0
                S = 1;
                valid_symbols = zeros(1, K, 'uint32');
                return;
            end

            combinations = nchoosek(1:m, beta);
            S = size(combinations, 1);
            valid_symbols = zeros(S, K, 'uint32');
            rows = (1:S).';
            for j = 1:beta
                bit_position = combinations(:, j);
                symbol_index = ceil(bit_position / r);
                exponent = r - mod(bit_position - 1, r) - 1;
                linear_index = sub2ind([S, K], rows, symbol_index);
                bit_value = bitshift(uint32(1), exponent);
                valid_symbols(linear_index) = bitxor( ...
                    valid_symbols(linear_index), bit_value);
            end

        otherwise
            error('Unsupported conference task: %s.', func_type);
    end
end
