function code_symbols = evaluate_rs_positions_vec(message_symbols, x, r, prim_poly)
%EVALUATE_RS_POSITIONS_VEC Evaluate each message polynomial at its paired x.

    x = uint32(x(:));
    num_messages = size(message_symbols, 1);
    if numel(x) == 1 && num_messages > 1
        x = repmat(x, num_messages, 1);
    end
    if numel(x) ~= num_messages
        error('There must be one evaluation point per message row.');
    end

    K = size(message_symbols, 2);
    code_symbols = message_symbols(:, K);
    for k = K-1:-1:1
        code_symbols = bitxor(gf_mul_vec(code_symbols, x, r, prim_poly), message_symbols(:, k));
    end
end
