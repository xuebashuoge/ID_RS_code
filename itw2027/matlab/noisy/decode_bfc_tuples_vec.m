function decoded = decode_bfc_tuples_vec(u, c, valid_symbols, r, K, L, memory_cfg, rs_length_mode)
%DECODE_BFC_TUPLES_VEC Apply the BFC region test to received (u,c) tuples.
%
% Positions are processed in bounded chunks. Invalid position bit patterns
% are treated as erasures and decode to false.

    if nargin < 8 || isempty(rs_length_mode)
        if L == 2^r
            rs_length_mode = 'extended';
        else
            rs_length_mode = 'distinct-nonzero';
        end
    end

    u = uint32(u(:));
    c = uint32(c(:));
    if numel(u) ~= numel(c)
        error('u and c must have the same number of elements.');
    end
    decoded = false(size(u));
    if isempty(u) || isempty(valid_symbols)
        return;
    end

    valid_rows = find(u >= 1 & double(u) <= L);
    if isempty(valid_rows)
        return;
    end

    S = size(valid_symbols, 1);
    bytes_budget = memory_cfg.region_working_mb * 2^20;
    % gf_mul_vec keeps several uint32/logical temporaries. Use a
    % conservative 24-byte working estimate per candidate.
    position_chunk = max(1, floor(bytes_budget / max(1, 24*double(S))));
    position_chunk = min(position_chunk, 256);

    prim_poly = get_primpoly(r);
    for start_idx = 1:position_chunk:numel(valid_rows)
        rows = valid_rows(start_idx:min(start_idx+position_chunk-1, numel(valid_rows)));
        x = rs_evaluation_points_at( ...
            r, u(rows), prim_poly, rs_length_mode).';
        candidates = repmat(valid_symbols(:, K), 1, numel(rows));
        for k = K-1:-1:1
            candidates = bitxor(gf_mul_vec(candidates, x, r, prim_poly), valid_symbols(:, k));
        end
        for j = 1:numel(rows)
            decoded(rows(j)) = ismember(c(rows(j)), candidates(:, j));
        end
    end
end
