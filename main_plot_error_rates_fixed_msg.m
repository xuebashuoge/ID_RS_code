% =========================================================================
% main_plot_error_rates_fixed_msg.m
%
% Runs simulation for EXACTLY ONE FIXED MESSAGE per n value.
% Position evaluation is vectorized and parallelized across position batches.
% =========================================================================
clear; close all;
tic

% --- 0. Initialize Parallel Pool ---
if isempty(gcp('nocreate'))
    try
        num_workers = feature('numcores');
        parpool('local', num_workers);
        fprintf('Parallel pool started with %d workers.\n', num_workers);
    catch ME
        fprintf('Warning: Could not start parallel pool (%s). Running serially.\n', ME.message);
    end
end

% --- 1. Simulation Parameters ---
E2 = 0.1;             % Code parameter
n_list_sim = 10:2:30;  % List of n values
num_trials_pos = 1e6; % Position Monte Carlo trials for the fixed message

% 'id (Constant weight S=1)' 
% 'exact-threshold (sum == beta)'         
% 'at-most-threshold (sum <= beta)'       
% 'bit-query (bit t == 1)'              
% 'and-subset (bits in S_k == 1)'    
% 'rank (int(b) <= rank)'      

func_type = 'rank';  % Choose the boolean function type
params.beta = 2;
params.t = 3;                         % Fallback for 'bit-query'
params.S_k = [1, 2];                  % Fallback for 'and-subset'
params.rank = 1000;                   % Fallback for 'rank'

% --- Setup Output Directory ---
results_dir = fullfile('results_temp', sprintf('fixed_msg_%s_E2_%.2f', func_type, E2));
if ~exist(results_dir, 'dir')
    mkdir(results_dir);
end
fprintf('=== Single Fixed Message BFC Plotting Simulation ===\n');
fprintf('Results will be saved to: %s\n', results_dir);

% --- 2. Run Simulations ---
sim_r_vals = zeros(1, length(n_list_sim));
sim_K_vals = zeros(1, length(n_list_sim));
sim_L_vals = zeros(1, length(n_list_sim));

fixed_fp_exact       = zeros(1, length(n_list_sim));
fixed_fp_mc          = zeros(1, length(n_list_sim));
fixed_R_vals         = zeros(1, length(n_list_sim));

expected_FP_rates    = zeros(1, length(n_list_sim));
theory_upper_bound   = zeros(1, length(n_list_sim));
sim_S_weights        = zeros(1, length(n_list_sim));
sim_rates            = zeros(1, length(n_list_sim));

for i = 1:length(n_list_sim)
    n = n_list_sim(i);
    r = n / 2;
    sim_r_vals(i) = r;
    L = 2^r;
    sim_L_vals(i) = L;
    K = K_calculator(n, E2, params, func_type);
    sim_K_vals(i) = K;
    m = r * K;
    % param.rank = floor(m / 2);  % Update rank parameter based on m

    fprintf('\nSimulating n = %d bits (r = %d, L = %d, K = %d, m = %d)...\n', n, r, L, K, m);

    % Target message definition
    params.target = randi([0 1], 1, m);

    % Build valid decoding regions
    [S_curr, D_ratio, valid_symbols_uint32] = build_decoding_regions_vec(r, K, L, func_type, params);
    sim_S_weights(i) = S_curr;
    sim_rates(i) = rate_calculation(n, m, func_type);

    expected_FP_rates(i) = mean(D_ratio) - S_curr / (2^m);
    theory_upper_bound(i) = S_curr * (K - 1) / L;

    % --- Single Fixed Message Generation ---
    weights_sym = 2.^((r-1):-1:0);
    target_symbols = zeros(1, K, 'uint32');
    for k = 1:K
        idx = (k-1)*r + 1 : k*r;
        target_symbols(k) = uint32(sum(params.target(idx) .* weights_sym));
    end

    field_size = 2^r;
    fixed_symbols = target_symbols;
    while all(fixed_symbols == target_symbols)
        fixed_symbols = uint32(randi([0, field_size - 1], 1, K));
    end

    % Run simulation for this single fixed message
    stat_single = run_monte_carlo_fixed_msg_vec(fixed_symbols, valid_symbols_uint32, r, K, L, func_type, params, num_trials_pos);
    fixed_fp_exact(i) = stat_single.fp_prob_exact;
    fixed_fp_mc(i)    = stat_single.fp_prob_mc;
    fixed_R_vals(i)   = stat_single.R;

    fprintf('Single Fixed Message: R = %d / %d -> Exact FP (R/L) = %.6f, MC Position FP = %.6f\n', ...
        stat_single.R, L, stat_single.fp_prob_exact, stat_single.fp_prob_mc);
    fprintf('Theoretical Expected FP: %.6f | Upper Bound S(K-1)/L: %.6f\n', ...
        expected_FP_rates(i), theory_upper_bound(i));

    % Save per-n result
    res_n = struct('n', n, 'r', r, 'L', L, 'K', K, 'm', m, ...
                   'fixed_symbols', fixed_symbols, ...
                   'stat_single', stat_single, ...
                   'expected_FP', expected_FP_rates(i), ...
                   'upper_bound', theory_upper_bound(i));
    save(fullfile(results_dir, sprintf('fixed_msg_result_n_%d.mat', n)), '-struct', 'res_n');
end

% --- Save Summary ---
save(fullfile(results_dir, 'summary_fixed_msg_all_n.mat'), ...
     'n_list_sim', 'sim_r_vals', 'sim_K_vals', 'sim_L_vals', ...
     'fixed_fp_exact', 'fixed_fp_mc', 'fixed_R_vals', ...
     'expected_FP_rates', 'theory_upper_bound');

% --- 3. Plotting ---
figure('Name', 'Single Fixed Message FP Simulation', 'Color', 'w', 'Position', [100, 100, 850, 600]);

semilogy(n_list_sim, fixed_fp_exact, 'bo-', 'LineWidth', 2, 'MarkerSize', 8, 'DisplayName', 'Single Fixed Msg (Exact R/L)');
hold on;
semilogy(n_list_sim, fixed_fp_mc, 'rx--', 'LineWidth', 1.5, 'MarkerSize', 8, 'DisplayName', 'Single Fixed Msg (Position MC)');
semilogy(n_list_sim, theory_upper_bound, 'r--', 'LineWidth', 2, 'DisplayName', 'Upper Bound: S(K-1)/L');
semilogy(n_list_sim, expected_FP_rates, 'k-.', 'LineWidth', 2, 'DisplayName', 'Theoretical Expected FP');

set(gca, 'YScale', 'log');
grid on; grid minor;
xlabel('n = log_2(L) + r', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('False Positive Probability (Log Scale)', 'FontSize', 12, 'FontWeight', 'bold');
title(sprintf('Single Fixed Message Error Rates vs. n (E2=%.2f, %s)', E2, func_type), 'FontSize', 14);
legend('Location', 'southwest', 'FontSize', 11);
xlim([floor(n_list_sim(1)), ceil(n_list_sim(end))]);

fig_filename = fullfile(results_dir, sprintf('Single_Fixed_Msg_Error_Rates_%s_E2_%.2f.png', func_type, E2));
saveas(gcf, fig_filename);
fprintf('\n=== Simulation Complete ===\nPlot saved to %s\n', fig_filename);
toc
