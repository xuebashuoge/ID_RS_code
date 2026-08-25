function coefficients = gf_polynomial_from_roots(roots, r, prim_poly)
%GF_POLYNOMIAL_FROM_ROOTS Return ascending coefficients of prod(x+root).

    coefficients = uint32(1);
    for index = 1:numel(roots)
        root = uint32(roots(index));
        old = coefficients;
        coefficients = zeros(1, numel(old) + 1, 'uint32');
        coefficients(1:end-1) = gf_mul_vec(old, root, r, prim_poly);
        coefficients(2:end) = bitxor(coefficients(2:end), old);
    end
end
