function d = derive_bfc_parameters(cfg, n)
%DERIVE_BFC_PARAMETERS Validate and derive scalar parameters for one n.

    validateattributes(n, {'numeric'}, {'scalar', 'integer', 'positive'});
    if mod(n, 2) ~= 0
        error('This simulation requires even n so that r=n/2 is integral.');
    end

    d.n = double(n);
    d.r = n / 2;
    if d.r > 32
        error('The custom GF implementation supports r <= 32.');
    end

    switch lower(cfg.bfc.rs_length_mode)
        case 'distinct-nonzero'
            d.L = 2^d.r - 1;
        case 'legacy'
            d.L = 2^d.r;
        otherwise
            error('Unknown RS length mode "%s".', cfg.bfc.rs_length_mode);
    end

    d.K = K_calculator(n, cfg.bfc.E2, cfg.bfc.params, cfg.bfc.func_type);
    if d.K < 1
        error('K_calculator returned K=%d for n=%d.', d.K, n);
    end
    d.m = d.r * d.K;

    d.ldpc_N = cfg.ldpc.block_length;
    d.ldpc_K = cfg.ldpc.information_length;
    d.tuples_per_frame = floor(d.ldpc_K / d.n);
    if d.tuples_per_frame < 1
        error('The BFC tuple is longer than the LDPC information block.');
    end
    d.payload_bits_per_frame = d.tuples_per_frame * d.n;
    d.padding_bits = d.ldpc_K - d.payload_bits_per_frame;
    d.effective_rate = d.payload_bits_per_frame / d.ldpc_N;
end
