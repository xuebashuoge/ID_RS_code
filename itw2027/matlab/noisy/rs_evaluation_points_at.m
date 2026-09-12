function eval_points = rs_evaluation_points_at(r, indices, prim_poly, rs_length_mode)
%RS_EVALUATION_POINTS_AT Return RS evaluation points for one-based indices.
%
% The extended ordering is
%   index 1 -> 0, index 2 -> 1, ..., index q -> alpha^(q-2), q=2^r.
% The distinct-nonzero ordering preserves the original noisy-channel
% convention index u -> alpha^u for u=1,...,q-1.
%
% This helper deliberately evaluates only the requested indices. It avoids
% materializing the complete q-point table in the noisy-channel source-bank
% and decoder paths.

    if nargin < 4 || isempty(rs_length_mode)
        rs_length_mode = 'extended';
    end
    rs_length_mode = lower(char(rs_length_mode));

    field_size = 2^r;
    index_values = double(indices);

    switch rs_length_mode
        case {'extended', 'legacy'}
            max_index = field_size;
        case 'distinct-nonzero'
            max_index = field_size - 1;
        otherwise
            error('Unknown RS length mode "%s".', rs_length_mode);
    end

    if any(~isfinite(index_values(:)) | ...
            index_values(:) ~= floor(index_values(:)) | ...
            index_values(:) < 1 | index_values(:) > max_index)
        error('RS indices must be integers in the configured valid range.');
    end

    indices = uint64(indices);
    eval_points = zeros(size(indices), 'uint32');

    switch rs_length_mode
        case {'extended', 'legacy'}
            needs_power = indices >= uint64(2);
            exponents = indices(needs_power) - uint64(2);
        case 'distinct-nonzero'
            needs_power = true(size(indices));
            exponents = indices;
    end

    if any(needs_power(:))
        alpha = uint32(2);
        if r == 1
            alpha = uint32(1);
        end
        eval_points(needs_power) = gf_pow_vec( ...
            alpha, exponents, r, prim_poly);
    end
end
