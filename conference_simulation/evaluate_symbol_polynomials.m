function values = evaluate_symbol_polynomials(coefficients, x_values, r, prim_poly)
%EVALUATE_SYMBOL_POLYNOMIALS Evaluate ascending-order GF coefficients.

    [num_polynomials, K] = size(coefficients);
    num_points = numel(x_values);
    x_values = reshape(uint32(x_values), 1, num_points);

    values = repmat(coefficients(:, K), 1, num_points);
    for k = (K - 1):-1:1
        values = bitxor( ...
            gf_mul_vec(values, x_values, r, prim_poly), coefficients(:, k));
    end

    if num_polynomials == 0
        values = zeros(0, num_points, 'uint32');
    end
end
