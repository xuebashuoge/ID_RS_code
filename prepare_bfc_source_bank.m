function bank = prepare_bfc_source_bank(cfg, n, bank_file)
%PREPARE_BFC_SOURCE_BANK Generate reusable balanced BFC tuple samples.
%
% The bank is deliberately independent of channel and Eb/N0. Expensive RS
% evaluation and noiseless decoding are therefore performed once per n.

    if nargin < 3
        bank_file = '';
    end
    if ~isempty(bank_file) && isfile(bank_file)
        loaded = load(bank_file, 'bank');
        bank = loaded.bank;
        validate_bank(bank, cfg, n);
        fprintf('Reusing compatible source bank %s (%d tuples)\n', ...
            bank_file, bank.metadata.total_tuples);
        return;
    end

    d = derive_bfc_parameters(cfg, n);
    rng(cfg.seed + 1009*n, 'twister');

    params = cfg.bfc.params;
    if strcmpi(cfg.bfc.func_type, 'id')
        if ~isfield(params, 'target') || numel(params.target) ~= d.m
            params.target = randi([0 1], 1, d.m);
        end
    end

    limits.max_valid_messages = cfg.memory.max_valid_messages;
    limits.max_valid_set_mb = cfg.memory.max_valid_set_mb;
    [S, valid_symbols, log2_p1] = build_valid_symbols_vec( ...
        d.r, d.K, cfg.bfc.func_type, params, limits);
    if S == 0
        error('The selected Boolean function has an empty acceptance set.');
    end

    total_tuples = cfg.mc.max_frames * d.tuples_per_frame;
    u = zeros(total_tuples, 1, 'uint32');
    c = zeros(total_tuples, 1, 'uint32');
    actual_f = mod((0:total_tuples-1)', 2) == 0;
    noiseless_f = false(total_tuples, 1);

    prim_poly = get_primpoly(d.r);
    alpha = uint32(2);
    batch_size = cfg.memory.sample_message_batch;
    fprintf('Preparing source bank: n=%d, K=%d, m=%d, S=%g, tuples=%d\n', ...
        d.n, d.K, d.m, S, total_tuples);

    for first = 1:batch_size:total_tuples
        rows = first:min(first+batch_size-1, total_tuples);
        labels = actual_f(rows);
        count = numel(rows);
        message_symbols = zeros(count, d.K, 'uint32');

        positive_rows = find(labels);
        if ~isempty(positive_rows)
            selected = randi(S, numel(positive_rows), 1);
            message_symbols(positive_rows, :) = valid_symbols(selected, :);
        end

        negative_rows = find(~labels);
        if ~isempty(negative_rows)
            message_symbols(negative_rows, :) = sample_negative_messages( ...
                numel(negative_rows), d, cfg.bfc.func_type, params, log2_p1, batch_size);
        end

        u(rows) = uint32(randi(d.L, count, 1));
        x = gf_pow_vec(alpha, u(rows), d.r, prim_poly);
        c(rows) = evaluate_rs_positions_vec(message_symbols, x, d.r, prim_poly);

        noiseless_f(rows(labels)) = true;
        if any(~labels)
            local_negative = find(~labels);
            decoded_negative = decode_bfc_tuples_vec( ...
                u(rows(local_negative)), c(rows(local_negative)), valid_symbols, ...
                d.r, d.K, d.L, cfg.memory);
            noiseless_f(rows(local_negative)) = decoded_negative;
        end

        if first == 1 || rows(end) == total_tuples || mod(first-1, 10*batch_size) == 0
            fprintf('  source tuples %d/%d\n', rows(end), total_tuples);
        end
    end

    bank.metadata.complete = true;
    bank.metadata.profile = cfg.profile;
    bank.metadata.seed = cfg.seed;
    bank.metadata.E2 = cfg.bfc.E2;
    bank.metadata.n = d.n;
    bank.metadata.r = d.r;
    bank.metadata.L = d.L;
    bank.metadata.K = d.K;
    bank.metadata.m = d.m;
    bank.metadata.S = S;
    bank.metadata.log2_p1 = log2_p1;
    bank.metadata.func_type = cfg.bfc.func_type;
    bank.metadata.params = params;
    bank.metadata.rs_length_mode = cfg.bfc.rs_length_mode;
    bank.metadata.tuples_per_frame = d.tuples_per_frame;
    bank.metadata.padding_bits = d.padding_bits;
    bank.metadata.total_tuples = total_tuples;
    bank.valid_symbols = valid_symbols;
    bank.u = u;
    bank.c = c;
    bank.actual_f = actual_f;
    bank.noiseless_f = noiseless_f;

    if ~isempty(bank_file)
        parent_dir = fileparts(bank_file);
        if ~exist(parent_dir, 'dir')
            mkdir(parent_dir);
        end
        temporary_file = [tempname(parent_dir) '.mat'];
        save(temporary_file, 'bank', '-v7.3');
        movefile(temporary_file, bank_file, 'f');
        fprintf('Saved source bank to %s\n', bank_file);
    end
end

function symbols = sample_negative_messages(count, d, func_type, params, log2_p1, batch_size)
    p_zero = 1 - 2^log2_p1;
    if p_zero < 0.01
        error(['Negative-message rejection sampling would accept fewer than 1%% ' ...
               'of candidates for this Boolean function.']);
    end

    symbols = zeros(count, d.K, 'uint32');
    filled = 0;
    field_size = 2^d.r;
    while filled < count
        needed = count - filled;
        proposal_count = min(batch_size, max(needed, ceil(1.2*needed/p_zero)));
        proposals = uint32(randi([0 field_size-1], proposal_count, d.K));
        bits = symbols_to_bits_logical(proposals, d.r);
        is_positive = evaluate_boolean_function_vec(bits, func_type, params);
        accepted = proposals(~is_positive, :);
        take = min(needed, size(accepted, 1));
        if take > 0
            symbols(filled+1:filled+take, :) = accepted(1:take, :);
            filled = filled + take;
        end
    end
end

function validate_bank(bank, cfg, n)
    if ~isfield(bank, 'metadata') || ~bank.metadata.complete
        error('Source bank is incomplete.');
    end
    if bank.metadata.n ~= n || ~strcmp(bank.metadata.func_type, cfg.bfc.func_type) || ...
            ~strcmp(bank.metadata.rs_length_mode, cfg.bfc.rs_length_mode)
        error('Source bank metadata does not match the requested configuration.');
    end
    expected = derive_bfc_parameters(cfg, n);
    if bank.metadata.r ~= expected.r || bank.metadata.L ~= expected.L || ...
            bank.metadata.K ~= expected.K || bank.metadata.m ~= expected.m
        error('Source bank BFC parameters do not match the requested configuration.');
    end
    if bank.metadata.total_tuples < cfg.mc.max_frames * expected.tuples_per_frame
        error('Source bank does not contain enough tuples for this profile.');
    end
end
