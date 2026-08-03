function eval_points = rs_evaluation_points(r, L, prim_poly)
    % rs_evaluation_points: Return L distinct points in GF(2^r).
    %
    % The extended RS ordering is:
    %   0, 1, alpha, alpha^2, ..., alpha^(L-2),
    % where alpha is a primitive element.  Including zero permits the
    % maximum length L = 2^r without repeating a nonzero field element.

    field_size = 2^r;
    if L < 1 || L ~= floor(L) || L > field_size
        error('L must be an integer in the range 1 <= L <= 2^r.');
    end

    eval_points = zeros(1, L, 'uint32');
    if L == 1
        return;
    end

    alpha = uint32(2);
    if r == 1
        alpha = uint32(1);
    end

    curr = uint32(1);
    for l = 2:L
        eval_points(l) = curr;
        if l < L
            curr = gf_mul_vec(curr, alpha, r, prim_poly);
        end
    end
end
