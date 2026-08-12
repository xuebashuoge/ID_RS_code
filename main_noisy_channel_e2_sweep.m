function output = main_noisy_channel_e2_sweep(profile, func_type, e2_values)
%MAIN_NOISY_CHANNEL_E2_SWEEP Sweep E2 while keeping LDPC rate at 1/2.
%
%   MAIN_NOISY_CHANNEL_E2_SWEEP('server_full', 'id') runs the default
%   E2=[0.05 0.10 0.15 0.20] AWGN experiment for n=[4 6 8].

    if nargin < 1
        profile = [];
    end
    if nargin < 2
        func_type = [];
    end
    if nargin < 3
        e2_values = [];
    end
    output = main_noisy_channel_tradeoff_sweep( ...
        'e2', profile, func_type, e2_values);
end
