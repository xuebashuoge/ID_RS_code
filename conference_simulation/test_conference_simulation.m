function test_conference_simulation()
%TEST_CONFERENCE_SIMULATION Small deterministic smoke tests.

    root_dir = fileparts(fileparts(mfilename('fullpath')));
    addpath(root_dir, fullfile(root_dir, 'conference_simulation'));
    cd(root_dir);
    pool = gcp('nocreate');
    if isempty(pool)
        start_conference_pool(2);
    end

    cfg = conference_config();
    rng(12345, 'twister');

    % Test exact-threshold support construction and negative sampling.
    r = 3;
    K = 2;
    L = 2^r;
    params = cfg.params;
    params.beta = 2;
    [S, support] = build_conference_support( ...
        r, K, 'exact-threshold', params);
    assert(S == nchoosek(r * K, params.beta));
    assert(size(unique(support, 'rows'), 1) == S);
    negatives = sample_uniform_negative_messages( ...
        20, r, K, 'exact-threshold', params);
    weights = zeros(size(negatives, 1), 1);
    for bit = 1:r
        weights = weights + sum(bitget(negatives, bit), 2);
    end
    assert(all(weights ~= params.beta));

    stat = exact_negative_fpr_distribution( ...
        support, negatives, r, L, 'ChunkSize', 4, ...
        'CheckpointEveryChunks', 1);
    prim_poly = get_primpoly(r);
    eval_points = rs_evaluation_points(r, L, prim_poly);
    support_values = evaluate_symbol_polynomials( ...
        support, eval_points, r, prim_poly);
    negative_values = evaluate_symbol_polynomials( ...
        negatives, eval_points, r, prim_poly);
    direct_counts = zeros(size(negatives, 1), 1);
    for position = 1:L
        direct_counts = direct_counts + ismember( ...
            negative_values(:, position), unique(support_values(:, position)));
    end
    assert(isequal(stat.R_counts, direct_counts));

    % Test the adversarial equality construction independently.
    r = 4;
    K = 3;
    L = 2^r;
    S = 3;
    [negative, adversarial_support] = build_adversarial_support(r, K, L, S);
    adversarial_stat = exact_negative_fpr_distribution( ...
        adversarial_support, negative, r, L, 'ChunkSize', 4, ...
        'CheckpointEveryChunks', 1);
    assert(adversarial_stat.R_counts(1) == S * (K - 1));
    assert(adversarial_stat.fpr_exact(1) == S * (K - 1) / L);

    % Test exact support-size formulas.
    assert(conference_support_size(120, 'exact-threshold', cfg.params) == 7140);
    assert(conference_support_size(100, 'rank', cfg.params) == 21);
    assert(conference_support_size(100, 'id', cfg.params) == 1);

    fprintf('All conference simulation smoke tests passed.\n');
end
