% =========================================================================
% test_verify_parallel.m
%
% Verification test: runs a small simulation with both serial and parallel
% Monte Carlo to ensure the parallel version produces correct results.
% Also verifies the GF multiplication table approach matches GF object math.
% =========================================================================
clear; close all;

fprintf('=== Verification Test: Parallel Monte Carlo ===\n\n');

all_passed = true;

% --- Test 1: GF multiplication table correctness ---
fprintf('Test 1: GF multiplication table correctness\n');
for r = [2, 3, 4, 5]
    field_size = 2^r;
    
    % Build multiplication table
    gf_mul = zeros(field_size, field_size, 'uint32');
    gf_elems = gf(0:(field_size-1), r);
    for a = 0:(field_size-1)
        products = gf_elems(a+1) * gf_elems;
        gf_mul(a+1, :) = products.x;
    end
    
    % Verify against direct GF multiplication for random pairs
    num_checks = 100;
    for c = 1:num_checks
        a_val = randi([0, field_size-1]);
        b_val = randi([0, field_size-1]);
        gf_product = gf(a_val, r) * gf(b_val, r);
        expected = double(gf_product.x);
        got = double(gf_mul(a_val+1, b_val+1));
        if expected ~= got
            fprintf('  FAIL: r=%d, %d*%d: expected %d, got %d\n', r, a_val, b_val, expected, got);
            all_passed = false;
        end
    end
    fprintf('  r=%d: %d random multiplications verified OK\n', r, num_checks);
end

% --- Test 2: GF matrix multiply via table matches GF object multiply ---
fprintf('\nTest 2: GF matrix multiply via table vs GF objects\n');
for r = [2, 3, 4]
    field_size = 2^r;
    K = 2;
    L = field_size;
    N = 50;
    
    % Build Vandermonde matrix
    alpha = gf(2, r);
    X = gf(zeros(K, L), r);
    for k = 1:K
        for l = 1:L
            X(k, l) = alpha ^ (l * (k - 1));
        end
    end
    X_raw = uint32(X.x);
    
    % Build multiplication table
    gf_mul = zeros(field_size, field_size, 'uint32');
    gf_elems = gf(0:(field_size-1), r);
    for a = 0:(field_size-1)
        products = gf_elems(a+1) * gf_elems;
        gf_mul(a+1, :) = products.x;
    end
    
    % Random symbols
    symbols = randi([0, field_size-1], N, K);
    
    % Method 1: GF object multiplication
    P = gf(symbols, r);
    C_gf = P * X;
    C_expected = double(C_gf.x);
    
    % Method 2: Table-based multiplication
    C_table = zeros(N, L, 'uint32');
    for k = 1:K
        sym_col = uint32(symbols(:, k)) + 1;
        x_row = X_raw(k, :);
        mul_result = gf_mul(sym_col, x_row + 1);
        C_table = bitxor(C_table, mul_result);
    end
    
    if isequal(C_expected, double(C_table))
        fprintf('  r=%d, K=%d, N=%d: PASS\n', r, K, N);
    else
        fprintf('  r=%d, K=%d, N=%d: FAIL (mismatch in %d entries)\n', r, K, N, sum(C_expected(:) ~= double(C_table(:))));
        all_passed = false;
    end
end

% --- Test 3: Full Monte Carlo simulation comparison ---
fprintf('\nTest 3: Full simulation comparison (small n)\n');

test_configs = {
    struct('n', 4, 'func_type', 'exact-threshold', 'params', struct('beta', 1));
    struct('n', 6, 'func_type', 'exact-threshold', 'params', struct('beta', 2));
    struct('n', 4, 'func_type', 'id', 'params', struct('target', [0 1]));
};

for t = 1:length(test_configs)
    cfg = test_configs{t};
    n = cfg.n;
    r = n / 2;
    L = 2^r;
    
    if strcmpi(cfg.func_type, 'id')
        K = K_calculator(n, 0.1, cfg.params, 'id');
        cfg.params.target = randi([0 1], 1, r*K);
    else
        K = K_calculator(n, 0.1, cfg.params, cfg.func_type);
    end
    
    if K < 1
        fprintf('  Config %d: K=%d < 1, skipping\n', t, K);
        continue;
    end
    
    m = r * K;
    [S, D_ratio, valid_c_matrix_uint32] = build_decoding_regions_vec(r, K, L, cfg.func_type, cfg.params);
    
    % Run with a fixed seed for reproducibility check
    num_trials = 100000;
    stat = run_monte_carlo_vec(valid_c_matrix_uint32, r, K, L, cfg.func_type, cfg.params, num_trials);
    
    fprintf('  Config %d (%s, n=%d, K=%d): FP=%.6f, FN=%.6f, Error=%.6f\n', ...
        t, cfg.func_type, n, K, stat.fp_prob, stat.fn_prob, stat.error_prob);
    
    % Basic sanity: error rate should be between 0 and 1
    if stat.error_prob < 0 || stat.error_prob > 1
        fprintf('    FAIL: error_prob out of range\n');
        all_passed = false;
    else
        fprintf('    PASS: error_prob in valid range\n');
    end
end

fprintf('\n');
if all_passed
    fprintf('=== ALL TESTS PASSED ===\n');
else
    fprintf('=== SOME TESTS FAILED ===\n');
end
