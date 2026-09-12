function [info_bits, payload_bits] = pack_bfc_tuples(u, c, r, ldpc_information_length, tuples_per_frame)
%PACK_BFC_TUPLES Pack [binary(u-1), binary(c)] tuples into LDPC frames.

    u = uint32(u(:));
    c = uint32(c(:));
    total_tuples = numel(u);
    if numel(c) ~= total_tuples || mod(total_tuples, tuples_per_frame) ~= 0
        error('Tuple arrays must have equal length and fill complete frames.');
    end

    bits = false(total_tuples, 2*r);
    u_zero = u - 1;
    for j = 1:r
        bits(:, j) = bitget(u_zero, r-j+1) ~= 0;
        bits(:, r+j) = bitget(c, r-j+1) ~= 0;
    end

    num_frames = total_tuples / tuples_per_frame;
    payload_length = tuples_per_frame * 2*r;
    payload_bits = reshape(bits.', payload_length, num_frames);
    info_bits = false(ldpc_information_length, num_frames);
    info_bits(1:payload_length, :) = payload_bits;
end
