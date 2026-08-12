function main_noisy_channel_sim(profile)
%MAIN_NOISY_CHANNEL_SIM Run a complete noisy-channel profile serially.
%
% With no input this runs only the two-frame local smoke profile. Use the
% supplied SLURM workflow for server_full rather than invoking it locally.

    if nargin < 1
        profile = 'local_smoke';
    end
    cfg = noisy_channel_config(profile);
    run_noisy_channel_configuration(cfg);
end
