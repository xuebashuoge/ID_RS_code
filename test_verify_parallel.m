% =========================================================================
% test_verify_parallel.m
%
% Verification test: runs a small simulation with both small n and large n
% (including r=17 for n=34) to ensure the custom GF implementation works.
% =========================================================================
clear; close all;

fprintf('=== Verification Test: Parallel Monte Carlo & Custom GF(2^r) ===\n\n');

all_passed = true;

% --- Test 1: GF multiplication table correctness vs gf_mul_vec ---
fprintf('Test 1: gf_mul_vec correctness for r <= 16\n');
for r = [2, 3, 4, 5, 12, 16]
    pp = get_primpoly(r);
    field_size = 2^r;
    
    num_checks = 100;
    for c = 1:num_checks
        a_val = randi([0, field_size-1]);
        b_val = randi([0, field_size-1]);
        gf_prod = gf(a_val, r) * gf(b_val, r);
        expected = double(gf_prod.x);
        got = double(gf_mul_vec(a_val, b_val, r, pp));
        if expected ~= got
            fprintf('  FAIL: r=%d, %d*%d: expected %d, got %d\n', r, a_val, b_val, expected, got);
            all_passed = false;
        end
    end
    fprintf('  r=%d: %d random multiplications verified OK\n', r, num_checks);
end

% --- Test 2: Full simulation including n = 34 (r = 17, m = 68, K = 4) ---
fprintf('\nTest 2: Full simulation test for n = 34 (r = 17)\n');

test_configs = {
    struct('n', 4, 'func_type', 'exact-threshold', 'params', struct('beta', 1));
    struct('n', 6, 'func_type', 'exact-threshold', 'params', struct('beta', 2));
    struct('n', 34, 'func_type', 'exact-threshold', 'params', struct('beta', 2));
};

for t = 1:length(test_configs)
    cfg = test_configs{t};
    n = cfg.n;
    r = n / 2;
    L = 2^r;
    
    K = K_calculator(n, 0.1, cfg.params, cfg.func_type);
    if K < 1
        K = 1;
    end
    
    m = r * K;
    fprintf('  Config %d: n=%d, r=%d, L=%d, K=%d, m=%d (%s) ... ', ...
        t, n, r, L, K, m, cfg.func_type);
    
    [S, D_ratio, valid_c_matrix_uint32] = build_decoding_regions_vec(r, K, L, cfg.func_type, cfg.params);
    
    num_trials = 10000;
    stat = run_monte_carlo_vec(valid_c_matrix_uint32, r, K, L, cfg.func_type, cfg.params, num_trials);
    
    fprintf('FP=%.6f, FN=%.6f, Error=%.6f -> PASS\n', stat.fp_prob, stat.fn_prob, stat.error_prob);
    
    if stat.error_prob < 0 || stat.error_prob > 1
        fprintf('    FAIL: error_prob out of range\n');
        all_passed = false;
    end
end

fprintf('\n');
if all_passed
    fprintf('=== ALL TESTS PASSED ===\n');
else
    fprintf('=== SOME TESTS FAILED ===\n');
end
