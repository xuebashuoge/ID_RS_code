function y = gf_pow_vec(base, exponent, r, prim_poly)
%GF_POW_VEC Memory-bounded vectorized exponentiation in GF(2^r).

    exponent = uint64(exponent);
    y = ones(size(exponent), 'uint32');
    factor = repmat(uint32(base), size(exponent));
    while any(exponent(:) ~= 0)
        multiply_mask = bitand(exponent, uint64(1)) ~= 0;
        if any(multiply_mask(:))
            y(multiply_mask) = gf_mul_vec(y(multiply_mask), factor(multiply_mask), r, prim_poly);
        end
        exponent = bitshift(exponent, -1);
        if any(exponent(:) ~= 0)
            factor = gf_mul_vec(factor, factor, r, prim_poly);
        end
    end
end
