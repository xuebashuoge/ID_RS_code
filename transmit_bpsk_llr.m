function [llr, channel_state] = transmit_bpsk_llr(bits, channel_type, ebno_db, effective_rate)
%TRANSMIT_BPSK_LLR BPSK channel model with correctly scaled soft output.
%
% Bit zero maps to +1. LLR is log(P(bit=0)/P(bit=1)).

    validateattributes(effective_rate, {'numeric'}, {'scalar', 'positive', '<=', 1});
    gamma_b = 10^(double(ebno_db)/10);
    N0 = 1 / (double(effective_rate) * gamma_b);
    tx = 1 - 2*single(bits);

    switch lower(channel_type)
        case 'awgn'
            noise = single(sqrt(N0/2)) .* randn(size(tx), 'single');
            rx = tx + noise;
            llr = single(4/N0) .* rx;
            channel_state = struct('N0', N0, 'effective_rate', effective_rate);

        case 'rayleigh'
            h = complex(randn(size(tx), 'single'), randn(size(tx), 'single'));
            h = h .* single(1/sqrt(2));
            noise = complex(randn(size(tx), 'single'), randn(size(tx), 'single'));
            noise = noise .* single(sqrt(N0/2));
            rx = h .* tx + noise;
            llr = single(4/N0) .* real(conj(h) .* rx);
            channel_state = struct('N0', N0, 'effective_rate', effective_rate);

        otherwise
            error('Unknown channel type "%s".', channel_type);
    end
end
