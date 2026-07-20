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
% --- 1. Simulation Parameters ---
% We MUST choose K=2 so that max(n) = log2(2^r - 1) + r ~ 2r = m
E2 = 0.1;           % Number of symbols
n_list_sim = 24:2:50;  % start from at least L <= 2^r - 1



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
params.rank = 1000;                   % Fallback for 'rank'

fprintf('=== BFC Plotting Simulation ===\n');

% --- 3. Run Empirical Simulations ---
sim_r_vals = zeros(1, length(n_list_sim));
sim_K_vals = zeros(1, length(n_list_sim));
sim_L_vals = zeros(1, length(n_list_sim));
sim_error_prob = zeros(1, length(n_list_sim));
sim_error_prob_baseline = zeros(1, length(n_list_sim));
sim_S_weights = zeros(1, length(n_list_sim));
sim_rates = zeros(1, length(n_list_sim));
expected_FP_rates = zeros(1, length(n_list_sim));

% We need the Hamming weight 'S' for the theoretical bound.
% It will be the same for all L, so we will extract it on the first loop.
for i = 1:length(n_list_sim)
    n = n_list_sim(i);
    r = n / 2;
    sim_r_vals(i) = r;
    L = 2^r;
    sim_L_vals(i) = L;
    K = K_calculator(n, E2, params, func_type);
    sim_K_vals(i) = K;
    m = r*K;       % Total message length in bits 

    num_trials = min(1e7, max(1e6, 10 * 2^m));
    
    fprintf('\nSimulating n = %d bits...\n', n);   
    fprintf('Message Length: m = %d bits, Alphabet Size: 2^%d, (%d,%d)-RS code\n', m, r, L, K);
    fprintf('Total Message Space: 2^%d\n', m);


    % construct id message
    params.target = randi([0 1], 1, m);   % Fallback for 'id'
    
    % Build decoding regions for this specific L
    [D, S_curr, D_ratio] = build_decoding_regions_vec(r, K, L, func_type, params);

    % calculate expected FP rate based on D_ratio (for debugging)
    if m < 50
        expected_FP_rates(i) = mean(D_ratio) - S_curr / 2^m;
    else
        expected_FP_rates(i) = mean(D_ratio);
    end
    
    sim_rates(i) = rate_calculation(n, m, func_type);
    fprintf('Rate: %.6f\n', sim_rates(i));
    
    sim_S_weights(i) = S_curr;
    fprintf('Hamming weight of boolean function (S): %d\n', S_curr);


    % Run Monte Carlo
    stat = run_monte_carlo_vec(D, r, K, L, func_type, params, num_trials);
    sim_error_prob(i) = stat.error_prob;
    sim_error_prob_baseline(i) = stat.error_prob_baseline;
    
    fprintf('Proposed FN: %.6f, FP: %.6f, Error: %.6f\nBaseline FN: %.6f, FP: %.6f, Error: %.6f\nExpected FP: %.6f\n', stat.fn_prob, stat.fp_prob, stat.error_prob, stat.fn_prob_baseline, stat.fp_prob_baseline, stat.error_prob_baseline, expected_FP_rates(i));
end

% --- 4. Compute Theoretical Bounds (Separated Calculation) ---
% We calculate these smoothly over a continuous range of n

% 4a. Upper Bound: S * (K - 1) / L
% Back-calculate continuous L from n: L = 2^(n - r)
theory_upper_bound = (sim_S_weights * (K - 1)) ./ sim_L_vals;



% --- 5. Plotting ---
figure('Name', 'BFC Error Probability', 'Color', 'w', 'Position', [100, 100, 800, 600]);

% Using semilogy for log scale on the Y-axis
semilogy(n_list_sim, sim_error_prob, 'bo-', 'LineWidth', 2, 'MarkerSize', 8, 'DisplayName', 'Simulated Empirical FP');
hold on;
semilogy(n_list_sim, sim_error_prob_baseline, 'bx-', 'LineWidth', 2, 'MarkerSize', 8, 'DisplayName', 'Baseline (always decode 0)');
semilogy(n_list_sim, theory_upper_bound, 'r--', 'LineWidth', 2, 'DisplayName', 'Upper Bound: S(K-1)/L');
semilogy(n_list_sim, expected_FP_rates, 'g-.', 'LineWidth', 2, 'DisplayName', 'Expected FP');

% --- ADDED: Loop to add text annotations for the rates ---
for i = 1:length(n_list_sim)
    % Only add text if the error probability > 0 (log(0) is undefined and won't plot properly)
    if sim_error_prob(i) > 0
        % Offset X slightly to the right (+0.2)
        % Multiply Y by 1.3 to push it visually "up" on the log scale
        if i == length(n_list_sim) % For the last point, offset to the left instead to avoid going out of bounds
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
title(sprintf('BFC Error Rate vs. n (K=%d, %s)', K, func_type), 'FontSize', 14);
legend('Location', 'southwest', 'FontSize', 11);
xlim([floor(n_list_sim(1)), ceil(n_list_sim(end))]);

% Enforce limits to make the plot visually clean
ylim([max(1e-6, min(sim_error_prob(sim_error_prob>0)) * 0.1), 1]);
saveas(gcf, sprintf('BFC_Error_Rates_%s_K%d_vec.png', func_type, K));

fprintf('\n=== Simulation Complete ===\nPlot has been generated.\n');
toc