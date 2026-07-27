#!/bin/bash

#=========================================================
# SLURM Job Script for Parallel Hyperparameter Sweep
#=========================================================

# Name of the job
#SBATCH --job-name=BFC_RS

# Output log files (%j will be replaced by the SLURM job ID)
#SBATCH --output=logs/sweep_%j.out
#SBATCH --error=logs/sweep_%j.err

#SBATCH --cpus-per-task=64
#SBATCH --time=48:00:00
#SBATCH --mem=1024G

module load MATLAB/2024b_Update_3

export SCRATCH="/tmp/${SLURM_JOB_ID}_${SLURM_ARRAY_TASK_ID}"
mkdir -p $SCRATCH
matlab -nodesktop -nosplash < main_plot_error_rates_fixed_msg.m

my-job-stats -a -n -s

echo "Job completed successfully."