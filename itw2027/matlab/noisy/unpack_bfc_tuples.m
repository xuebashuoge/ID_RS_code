function [u, c] = unpack_bfc_tuples(payload_bits, r)
%UNPACK_BFC_TUPLES Restore one-based u and uint32 c from payload bits.

    tuple_width = 2*r;
    if mod(numel(payload_bits), tuple_width) ~= 0
        error('Payload size is not a whole number of BFC tuples.');
    end
    bits = reshape(logical(payload_bits), tuple_width, []).';
    u_zero = zeros(size(bits, 1), 1, 'uint32');
    c = zeros(size(bits, 1), 1, 'uint32');
    for j = 1:r
        u_zero = bitor(bitshift(u_zero, 1), uint32(bits(:, j)));
        c = bitor(bitshift(c, 1), uint32(bits(:, r+j)));
    end
    u = u_zero + 1;
end
