function symbols = positions_to_symbols(combos, r, K)
%POSITIONS_TO_SYMBOLS Convert rows of one-bit positions to GF message symbols.

    num_rows = size(combos, 1);
    symbols = zeros(num_rows, K, 'uint32');
    for j = 1:size(combos, 2)
        positions = combos(:, j);
        symbol_index = ceil(positions / r);
        offset = mod(positions - 1, r);
        bit_value = bitshift(uint32(1), r - 1 - offset);
        for k = 1:K
            mask = symbol_index == k;
            if any(mask)
                symbols(mask, k) = bitor(symbols(mask, k), bit_value(mask));
            end
        end
    end
end
