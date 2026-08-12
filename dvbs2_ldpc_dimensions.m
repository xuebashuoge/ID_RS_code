function [block_length, information_length, code_rate] = dvbs2_ldpc_dimensions(code_rate)
%DVBS2_LDPC_DIMENSIONS Dimensions of a normal-frame DVB-S2 LDPC code.
%
%   [N, K, R] = DVBS2_LDPC_DIMENSIONS(RATE) validates RATE against the
%   rates supported by MATLAB's dvbs2ldpc normal-frame implementation and
%   returns N=64800 and K=N*R.

    validateattributes(code_rate, {'numeric'}, ...
        {'scalar', 'real', 'finite', 'positive', '<', 1});

    supported_rates = [1/4, 1/3, 2/5, 1/2, 3/5, 2/3, ...
        3/4, 4/5, 5/6, 8/9, 9/10];
    [distance, rate_index] = min(abs(double(code_rate) - supported_rates));
    if distance > 1e-12
        error('Unsupported DVB-S2 LDPC rate %.12g.', code_rate);
    end

    code_rate = supported_rates(rate_index);
    block_length = 64800;
    information_length = round(block_length * code_rate);
end
