function [D, S, D_ratio] = build_decoding_regions_vec(r, K, L, func_type, params)
    % build_decoding_regions: Determines valid GF symbols at each position
    %
    % Inputs:
    %   r, K, L, func_type, params - Configuration
    %
    % Outputs:
    %   D - Cell array of size [1 x L]. D{l} contains a GF array of symbols
    %   S - Hamming weight of the boolean function
    %   D_ratio - Ratio of valid symbols to total symbols in each decoding region
    
    % Initialize D as empty Galois Field arrays
    D = cell(1, L);
    for l = 1:L
        D{l} = gf([], r);
    end

    if strcmpi(func_type, 'id')
        % For 'id', the only valid message is the target message itself
        valid_b_matrix = params.target;
        S = 1;
    else
        total_messages = 2^(r * K);
        if total_messages > 1e7
            error('Message space 2^(r*K) = 2^%d is too large to list all messages. For large messages, use func_type = ''id''.', r*K);
        end
        % Generate all messages integers
        msg_ints = (0:(total_messages - 1))';

        % convert to binary matrix (N x m)
        weights_b = 2.^((r*K-1):-1:0);
        b_matrix = rem(floor(msg_ints ./ weights_b), 2);

        % Evaluate boolean function for all messages at once
        func_outputs = evaluate_boolean_function_vec(b_matrix, func_type, params);

        % Filter messages to pre-image of 1
        valid_b_matrix = b_matrix(func_outputs, :);
        S = size(valid_b_matrix, 1);
    end

    % Encode valid messages to get codewords
    valid_c_matrix = rs_encode_polynomial_vec(valid_b_matrix, r, K, L);

    % Add symbols to respective decoding regions
    D_ratio = zeros(1, L);
    for l = 1:L
        valid_c_ints = valid_c_matrix(:, l);
        unique_ints = unique(valid_c_ints.x);
        D{l} = gf(unique_ints, r);
        D_ratio(l) = size(unique_ints, 1) / 2^r;
    end
end