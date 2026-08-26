%RUN_PLOT_NOISY_CHANNEL_CONFIRMATORY_TASK SLURM plotting entry point.
experiment = getenv('BFC_CONFIRMATORY_EXPERIMENT');
if isempty(experiment)
    experiment = 'waterfall';
end
plot_noisy_channel_confirmatory_results(experiment);
