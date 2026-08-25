function negative_symbols = sample_uniform_negative_messages( ...
    num_messages, r, K, func_type, params)
%SAMPLE_UNIFORM_NEGATIVE_MESSAGES Sample exactly from I | f(I)=0.

    q = 2^r;
    negative_symbols = zeros(num_messages, K, 'uint32');
    accepted = 0;

    while accepted < num_messages
        remaining = num_messages - accepted;
        batch_size = max(64, ceil(1.05 * remaining));
        candidates = uint32(randi([0, q - 1], batch_size, K));

        switch lower(func_type)
            case 'id'
                is_positive = all(candidates == params.target_symbols, 2);

            case 'rank'
                % The conference rank is small. Compare its base-q symbols
                % without converting the full message to a floating-point int.
                is_positive = all(candidates(:, 1:(K - 1)) == 0, 2) & ...
                    candidates(:, K) <= uint32(params.rank);

            case 'exact-threshold'
                weights = zeros(batch_size, 1);
                for bit = 1:r
                    weights = weights + sum(bitget(candidates, bit), 2);
                end
                is_positive = (weights == params.beta);

            otherwise
                error('Unsupported conference task: %s.', func_type);
        end

        candidates = candidates(~is_positive, :);
        take = min(size(candidates, 1), remaining);
        negative_symbols((accepted + 1):(accepted + take), :) = ...
            candidates(1:take, :);
        accepted = accepted + take;
    end
end
