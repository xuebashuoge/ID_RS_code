function q = empirical_quantile(values, probabilities)
%EMPIRICAL_QUANTILE Linear empirical quantiles without toolbox dependencies.

    values = sort(values(:));
    probabilities = probabilities(:).';
    if isempty(values)
        q = nan(size(probabilities));
        return;
    end
    if any(probabilities < 0 | probabilities > 1)
        error('Quantile probabilities must lie in [0, 1].');
    end

    positions = 1 + (numel(values) - 1) .* probabilities;
    lower_index = floor(positions);
    upper_index = ceil(positions);
    fraction = positions - lower_index;
    q = values(lower_index).' .* (1 - fraction) + ...
        values(upper_index).' .* fraction;
end
