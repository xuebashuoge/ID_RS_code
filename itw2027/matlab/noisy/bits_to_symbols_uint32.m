function symbols = bits_to_symbols_uint32(bits, r)
%BITS_TO_SYMBOLS_UINT32 Convert MSB-first binary rows into GF symbol rows.

    [num_rows, m] = size(bits);
    if mod(m, r) ~= 0
        error('The bit width must be a multiple of r.');
    end
    K = m / r;
    symbols = zeros(num_rows, K, 'uint32');
    for k = 1:K
        value = zeros(num_rows, 1, 'uint32');
        for j = 1:r
            value = bitor(bitshift(value, 1), uint32(bits(:, (k-1)*r + j)));
        end
        symbols(:, k) = value;
    end
end
