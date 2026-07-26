% =========================================================================
% main_plot_BFC.m
%
% Plots empirical false-positive probabilities against theoretical upper 
% bounds error rates.
% X-axis: n = log2(L) + r
% Y-axis: log(error probability)
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
% We MUST choose K=2 so that max(n) = log2(2^r - 1) + r ~ 2r = m
E2 = 0.1;           % Number of symbols
n_list_sim = 44:2:50;  % start from at least L <= 2^r - 1



% 'id (Constant weight S=1)' 
% 'exact-threshold (sum == beta)'         
% 'at-most-threshold (sum <= beta)'       
% 'bit-query (bit t == 1)'              
% 'and-subset (bits in S_k == 1)'    
% 'rank (int(b) <= rank)'         

% --- 2. Boolean Function Setup ---
func_type = 'exact-threshold';  % Choose the boolean function type
params.beta = 2;                      % Target threshold
% params.target = randi([0 1], 1, m);   % Fallback for 'id'
params.t = 3;                         % Fallback for 'bit-query'
params.S_k = [1, 2];                  % Fallback for 'and-subset'
params.rank = 20;                   % Fallback for 'rank'

% --- Setup Output Directory ---
results_dir = fullfile('results_temp', sprintf('%s_E2_%.2f', func_type, E2));
if ~exist(results_dir, 'dir')
    mkdir(results_dir);
end
fprintf('=== BFC Plotting Simulation ===\n');
fprintf('Results will be saved to: %s\n', results_dir);

% --- 3. Run Empirical Simulations ---
sim_r_vals = zeros(1, length(n_list_sim));
sim_K_vals = zeros(1, length(n_list_sim));
sim_L_vals = zeros(1, length(n_list_sim));
sim_error_prob = zeros(1, length(n_list_sim));
sim_error_prob_baseline = zeros(1, length(n_list_sim));
sim_S_weights = zeros(1, length(n_list_sim));
sim_rates = zeros(1, length(n_list_sim));
expected_FP_rates = zeros(1, length(n_list_sim));

for i = 1:length(n_list_sim)
    n = n_list_sim(i);
    r = n / 2;
    sim_r_vals(i) = r;
    L = 2^r;
    sim_L_vals(i) = L;
    K = K_calculator(n, E2, params, func_type);
    sim_K_vals(i) = K;
    m = r*K;       % Total message length in bits 

    num_trials = min(1e8, max(1e6, 10 * 2^m));
    
    fprintf('\nSimulating n = %d bits...\n', n);   
    fprintf('Message Length: m = %d bits, Alphabet Size: 2^%d, (%d,%d)-RS code\n', m, r, L, K);
    fprintf('Total Message Space: 2^%d\n', m);

    % construct id message
    params.target = randi([0 1], 1, m);   % Fallback for 'id'
    
    % Build decoding regions for this specific L
    [S_curr, D_ratio, valid_symbols_uint32] = build_decoding_regions_vec(r, K, L, func_type, params);

    expected_FP_rates(i) = mean(D_ratio) - S_curr / 2^m;
    
    sim_rates(i) = rate_calculation(n, m, func_type);
    fprintf('Rate: %.6f\n', sim_rates(i));
    
    sim_S_weights(i) = S_curr;
    fprintf('Hamming weight of boolean function (S): %d\n', S_curr);

    % Run Monte Carlo
    stat = run_monte_carlo_vec(valid_symbols_uint32, r, K, L, func_type, params, num_trials);
    sim_error_prob(i) = stat.error_prob;
    sim_error_prob_baseline(i) = stat.error_prob_baseline;
    
    fprintf('Proposed FN: %.6f, FP: %.6f, Error: %.6f\nBaseline FN: %.6f, FP: %.6f, Error: %.6f\nExpected FP: %.6f\n', stat.fn_prob, stat.fp_prob, stat.error_prob, stat.fn_prob_baseline, stat.fp_prob_baseline, stat.error_prob_baseline, expected_FP_rates(i));

    % Save individual result for this n
    res_n = struct('n', n, 'r', r, 'L', L, 'K', K, 'm', m, 'S', S_curr, 'rate', sim_rates(i), 'stat', stat, 'expected_FP', expected_FP_rates(i));
    save(fullfile(results_dir, sprintf('result_n_%d.mat', n)), '-struct', 'res_n');
    fprintf('Saved result for n = %d to %s\n', n, fullfile(results_dir, sprintf('result_n_%d.mat', n)));
end

% --- 4. Compute Theoretical Bounds (Separated Calculation) ---
% We calculate these smoothly over a continuous range of n

% 4a. Upper Bound: S * (K - 1) / L
% Back-calculate continuous L from n: L = 2^(n - r)
theory_upper_bound = (sim_S_weights .* (sim_K_vals - 1)) ./ sim_L_vals;

% Save all summary vectors
save(fullfile(results_dir, 'summary_all_n.mat'), 'n_list_sim', 'sim_r_vals', 'sim_K_vals', 'sim_L_vals', 'sim_error_prob', 'sim_error_prob_baseline', 'sim_S_weights', 'sim_rates', 'expected_FP_rates', 'theory_upper_bound');

% Save all summary vectors
save(fullfile(results_dir, 'summary_all_n.mat'), 'n_list_sim', 'sim_r_vals', 'sim_K_vals', ...
     'sim_L_vals', 'sim_error_prob', 'sim_error_prob_baseline', 'sim_S_weights', ...
     'sim_rates', 'expected_FP_rates', 'theory_upper_bound');

% --- 5. Plotting ---
figure('Name', 'BFC Error Probability', 'Color', 'w', 'Position', [100, 100, 800, 600]);

% Using semilogy for log scale on the Y-axis
semilogy(n_list_sim, sim_error_prob, 'bo-', 'LineWidth', 2, 'MarkerSize', 8, 'DisplayName', 'Simulated Empirical FP');
hold on;
semilogy(n_list_sim, sim_error_prob_baseline, 'bx-', 'LineWidth', 2, 'MarkerSize', 8, 'DisplayName', 'Baseline (always decode 0)');
semilogy(n_list_sim, theory_upper_bound, 'r--', 'LineWidth', 2, 'DisplayName', 'Upper Bound: S(K-1)/L');
semilogy(n_list_sim, expected_FP_rates, 'g-.', 'LineWidth', 2, 'DisplayName', 'Expected FP');

% Ensure Y-axis is explicitly set to log scale
set(gca, 'YScale', 'log');

% Loop to add text annotations for the rates
for i = 1:length(n_list_sim)
    if sim_error_prob(i) > 0
        if i == length(n_list_sim)
            text(n_list_sim(i) - 0.5, sim_error_prob(i) * 1.3, sprintf('R=%.3f', sim_rates(i)), 'Color', 'b', 'FontSize', 12, 'FontWeight', 'bold');
        elseif i == 1
            text(n_list_sim(i) + 0.2, sim_error_prob(i) * 1.3, sprintf('R=%.3f', sim_rates(i)), 'Color', 'b', 'FontSize', 12, 'FontWeight', 'bold');
        else
            text(n_list_sim(i) - 0.2, sim_error_prob(i) * 1.3, sprintf('R=%.3f', sim_rates(i)), 'Color', 'b', 'FontSize', 12, 'FontWeight', 'bold');
        end
    end
end

% Formatting
grid on;
grid minor;
xlabel('n = log_2(L) + r', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('Error Probability (Log Scale)', 'FontSize', 12, 'FontWeight', 'bold');
title(sprintf('BFC Error Rate vs. n (E2=%.2f, %s)', E2, func_type), 'FontSize', 14);
legend('Location', 'southwest', 'FontSize', 11);
xlim([floor(n_list_sim(1)), ceil(n_list_sim(end))]);

% Enforce limits to make the plot visually clean
ylim([max(1e-6, min(sim_error_prob(sim_error_prob>0)) * 0.1), 1]);

fig_filename = fullfile(results_dir, sprintf('BFC_Error_Rates_%s_E2_%.2f.png', func_type, E2));
saveas(gcf, fig_filename);
fprintf('\n=== Simulation Complete ===\nPlot saved to %s\n', fig_filename);
toc