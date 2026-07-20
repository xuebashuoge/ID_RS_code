% =========================================================================
% test_verify_build_decoding.m
%
% Verification test: compares the new combinatorial build_decoding_regions_vec
% against a brute-force reference implementation for small n values.
%
% For each test case, both approaches must produce identical D, S, and D_ratio.
% =========================================================================
clear; close all;

fprintf('=== Verification Test: build_decoding_regions_vec ===\n\n');

all_passed = true;

% --- Test cases ---
test_cases = {};

% Test exact-threshold for several n values
for n = [4, 6, 8, 10]
    r = n / 2;
    L = 2^r;
    for beta = [1, 2, 3]
        params_test = struct('beta', beta);
        E2 = 0.1;
        K = K_calculator(n, E2, params_test, 'exact-threshold');
        if K < 1
            continue;
        end
        tc.n = n; tc.r = r; tc.K = K; tc.L = L;
        tc.func_type = 'exact-threshold';
        tc.params = params_test;
        tc.label = sprintf('exact-threshold n=%d beta=%d K=%d', n, beta, K);
        test_cases{end+1} = tc;
    end
end

% Test at-most-threshold for several n values
for n = [4, 6, 8, 10]
    r = n / 2;
    L = 2^r;
    for beta = [1, 2, 3]
        params_test = struct('beta', beta);
        E2 = 0.1;
        K = K_calculator(n, E2, params_test, 'at-most-threshold');
        if K < 1
            continue;
        end
        tc.n = n; tc.r = r; tc.K = K; tc.L = L;
        tc.func_type = 'at-most-threshold';
        tc.params = params_test;
        tc.label = sprintf('at-most-threshold n=%d beta=%d K=%d', n, beta, K);
        test_cases{end+1} = tc;
    end
end

% Test bit-query
for n = [4, 6, 8]
    r = n / 2;
    L = 2^r;
    params_test = struct('t', 1);
    E2 = 0.1;
    K = K_calculator(n, E2, params_test, 'bit-query');
    if K < 1
        continue;
    end
    tc.n = n; tc.r = r; tc.K = K; tc.L = L;
    tc.func_type = 'bit-query';
    tc.params = params_test;
    tc.label = sprintf('bit-query n=%d t=%d K=%d', n, params_test.t, K);
    test_cases{end+1} = tc;
end

% Test rank
for n = [4, 6, 8]
    r = n / 2;
    L = 2^r;
    params_test = struct('rank', 5);
    E2 = 0.1;
    K = K_calculator(n, E2, params_test, 'rank');
    if K < 1
        continue;
    end
    tc.n = n; tc.r = r; tc.K = K; tc.L = L;
    tc.func_type = 'rank';
    tc.params = params_test;
    tc.label = sprintf('rank n=%d rank=%d K=%d', n, params_test.rank, K);
    test_cases{end+1} = tc;
end

% --- Run all tests ---
fprintf('Running %d test cases...\n\n', length(test_cases));

for i = 1:length(test_cases)
    tc = test_cases{i};
    fprintf('Test %2d: %-45s ... ', i, tc.label);

    % Run new implementation
    [D_new, S_new, D_ratio_new] = build_decoding_regions_vec(tc.r, tc.K, tc.L, tc.func_type, tc.params);

    % Run brute-force reference
    [D_ref, S_ref, D_ratio_ref] = build_decoding_regions_bruteforce(tc.r, tc.K, tc.L, tc.func_type, tc.params);

    % Compare S
    if S_new ~= S_ref
        fprintf('FAIL (S mismatch: new=%d, ref=%d)\n', S_new, S_ref);
        all_passed = false;
        continue;
    end

    % Compare D_ratio
    if max(abs(D_ratio_new - D_ratio_ref)) > 1e-12
        fprintf('FAIL (D_ratio mismatch, max diff=%.2e)\n', max(abs(D_ratio_new - D_ratio_ref)));
        all_passed = false;
        continue;
    end

    % Compare D cell arrays
    d_match = true;
    for l = 1:tc.L
        vals_new = sort(D_new{l}.x);
        vals_ref = sort(D_ref{l}.x);
        if ~isequal(vals_new, vals_ref)
            d_match = false;
            break;
        end
    end

    if ~d_match
        fprintf('FAIL (D mismatch at position l=%d)\n', l);
        all_passed = false;
    else
        fprintf('PASS (S=%d)\n', S_new);
    end
end

fprintf('\n');
if all_passed
    fprintf('=== ALL %d TESTS PASSED ===\n', length(test_cases));
else
    fprintf('=== SOME TESTS FAILED ===\n');
end
