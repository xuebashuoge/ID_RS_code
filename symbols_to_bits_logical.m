function bits = symbols_to_bits_logical(symbols, r)
%SYMBOLS_TO_BITS_LOGICAL Convert GF symbol rows into MSB-first logical bits.

    [num_rows, K] = size(symbols);
    bits = false(num_rows, K*r);
    for k = 1:K
        for j = 1:r
            bits(:, (k-1)*r + j) = bitget(symbols(:, k), r-j+1) ~= 0;
        end
    end
end
