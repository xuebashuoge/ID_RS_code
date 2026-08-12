function output = main_noisy_channel_ldpc_rate_sweep( ...
        profile, func_type, rate_values)
%MAIN_NOISY_CHANNEL_LDPC_RATE_SWEEP Sweep DVB-S2 LDPC rate at E2=0.1.
%
%   MAIN_NOISY_CHANNEL_LDPC_RATE_SWEEP('server_full', 'id') runs the
%   default R_c=[1/3 2/5 1/2 3/5 2/3] AWGN experiment for n=[4 6 8].

    if nargin < 1
        profile = [];
    end
    if nargin < 2
        func_type = [];
    end
    if nargin < 3
        rate_values = [];
    end
    output = main_noisy_channel_tradeoff_sweep( ...
        'ldpc_rate', profile, func_type, rate_values);
end
