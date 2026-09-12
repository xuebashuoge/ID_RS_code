function [S, valid_symbols_uint32, log2_p1] = build_valid_symbols_vec(r, K, func_type, params, limits)
%BUILD_VALID_SYMBOLS_VEC Enumerate accepted messages directly in symbol form.
%
% This avoids the large S-by-(r*K) double matrix used by the original
% decoding-region builder. Configurations with inherently non-enumerable
% acceptance sets are rejected before allocation.

    if nargin < 5
        limits.max_valid_messages = 5e6;
        limits.max_valid_set_mb = 1024;
    end
    m = r * K;

    switch lower(func_type)
        case 'id'
            S = 1;
            valid_symbols_uint32 = bits_to_symbols_uint32(logical(params.target), r);

        case 'exact-threshold'
            beta = params.beta;
            if beta < 0 || beta > m
                S = 0;
                valid_symbols_uint32 = zeros(0, K, 'uint32');
            elseif beta == 0
                S = 1;
                valid_symbols_uint32 = zeros(1, K, 'uint32');
            else
                S = nchoosek(m, beta);
                validate_enumeration_size(S, K, limits);
                combos = nchoosek(1:m, beta);
                valid_symbols_uint32 = positions_to_symbols(combos, r, K);
            end

        case 'at-most-threshold'
            beta = min(max(params.beta, 0), m);
            counts = zeros(1, beta+1);
            for weight = 0:beta
                counts(weight+1) = nchoosek(m, weight);
            end
            S = sum(counts);
            validate_enumeration_size(S, K, limits);
            valid_symbols_uint32 = zeros(S, K, 'uint32');
            row = 2; % Row one is the all-zero word.
            for weight = 1:beta
                combos = nchoosek(1:m, weight);
                count = size(combos, 1);
                valid_symbols_uint32(row:row+count-1, :) = positions_to_symbols(combos, r, K);
                row = row + count;
            end

        case 'rank'
            S = double(params.rank) + 1;
            validate_enumeration_size(S, K, limits);
            values = uint64((0:S-1)');
            valid_symbols_uint32 = zeros(S, K, 'uint32');
            symbol_mask = bitshift(uint64(1), r) - 1;
            for k = 1:K
                right_bits = m - k*r;
                if right_bits >= 64
                    continue;
                end
                valid_symbols_uint32(:, k) = uint32(bitand(bitshift(values, -right_bits), symbol_mask));
            end

        case {'bit-query', 'and-subset'}
            total_messages = 2^m;
            if strcmpi(func_type, 'bit-query')
                S = 2^(m-1);
            else
                S = 2^(m-length(params.S_k));
            end
            validate_enumeration_size(S, K, limits);
            if total_messages > 2*limits.max_valid_messages
                error('Total message enumeration (%g rows) exceeds the configured limit.', total_messages);
            end
            values = uint64((0:total_messages-1)');
            bits = false(total_messages, m);
            for j = 1:min(m, 64)
                bits(:, m-j+1) = bitget(values, j) ~= 0;
            end
            accepted = evaluate_boolean_function_vec(bits, func_type, params);
            valid_symbols_uint32 = bits_to_symbols_uint32(bits(accepted, :), r);
            S = size(valid_symbols_uint32, 1);

        otherwise
            error('Unknown boolean function type "%s".', func_type);
    end

    if S == 0
        log2_p1 = -Inf;
    else
        log2_p1 = log2(double(S)) - m;
    end
end

function validate_enumeration_size(S, K, limits)
    estimated_mb = double(S) * double(K) * 4 / 2^20;
    if S > limits.max_valid_messages
        error('Acceptance set S=%g exceeds max_valid_messages=%g.', ...
            S, limits.max_valid_messages);
    end
    if estimated_mb > limits.max_valid_set_mb
        error('Acceptance set needs at least %.1f MB, above the %.1f MB limit.', ...
            estimated_mb, limits.max_valid_set_mb);
    end
end
