%TEST_NOISY_CHANNEL_COMPONENTS Deterministic component and end-to-end checks.
clear;
fprintf('=== Noisy-channel component tests ===\n');
rng(1234, 'twister');

%% Bit/symbol conversion
for r = [2 4 8]
    bits = rand(37, 3*r) > 0.5;
    symbols = bits_to_symbols_uint32(bits, r);
    reconstructed = symbols_to_bits_logical(symbols, r);
    assert(isequal(bits, reconstructed));
end
fprintf('PASS: bit/symbol conversion\n');

%% On-demand GF powers
r = 4;
pp = get_primpoly(r);
exponents = uint32((0:15)');
got = gf_pow_vec(uint32(2), exponents, r, pp);
expected = ones(size(exponents), 'uint32');
for idx = 2:numel(exponents)
    expected(idx) = gf_mul_vec(expected(idx-1), uint32(2), r, pp);
end
assert(isequal(got, expected));
fprintf('PASS: GF exponentiation\n');

%% Sampled RS evaluation equals the full encoder
r = 4;
K = 2;
L = 2^r - 1;
bits = rand(25, r*K) > 0.5;
symbols = bits_to_symbols_uint32(bits, r);
full_codeword = rs_encode_polynomial_vec(bits, r, K, L);
u = uint32(randi(L, size(bits, 1), 1));
evaluation_points = rs_evaluation_points(r, L, get_primpoly(r));
x = evaluation_points(double(u));
sampled = evaluate_rs_positions_vec(symbols, x, r, get_primpoly(r));
linear_index = sub2ind(size(full_codeword), (1:size(bits,1))', double(u));
assert(isequal(sampled, full_codeword(linear_index)));
fprintf('PASS: sampled RS evaluation\n');

%% Direct valid-set builder agrees with the original small implementation
params = struct('beta', 2);
limits.max_valid_messages = 1e5;
limits.max_valid_set_mb = 64;
[S_new, valid_symbols, log2_p1] = build_valid_symbols_vec(4, 2, ...
    'exact-threshold', params, limits);
[S_old, ~, valid_symbols_old] = build_decoding_regions_vec(4, 2, 15, ...
    'exact-threshold', params);
assert(S_new == S_old);
assert(isequal(sortrows(valid_symbols), sortrows(valid_symbols_old)));
assert(abs(log2_p1 - (log2(S_new)-8)) < 1e-12);
fprintf('PASS: valid-set construction\n');

%% Tuple packing, padding, and invalid-index erasure
u = uint32([1; 15; 3; 8]);
c = uint32([0; 15; 6; 9]);
[info_bits, payload_bits] = pack_bfc_tuples(u, c, 4, 21, 2);
assert(isequal(size(info_bits), [21 2]));
assert(all(info_bits(17:end, :) == 0, 'all'));
[u_roundtrip, c_roundtrip] = unpack_bfc_tuples(payload_bits, 4);
assert(isequal(u, u_roundtrip) && isequal(c, c_roundtrip));
decoded_invalid = decode_bfc_tuples_vec(uint32(16), uint32(0), ...
    valid_symbols, 4, 2, 15, struct('region_working_mb', 16));
assert(~decoded_invalid);
fprintf('PASS: tuple framing and invalid-index handling\n');

%% Rate bookkeeping and controlled sweep configurations
[ldpc_N, ldpc_K, canonical_rate] = dvbs2_ldpc_dimensions(3/5);
assert(ldpc_N == 64800 && ldpc_K == 38880 && canonical_rate == 3/5);

base_cfg = noisy_channel_config('local_smoke');
base_cfg.bfc.func_type = 'id';
d4 = derive_bfc_parameters(base_cfg, 4);
assert(d4.tuples_per_frame == 8100);
assert(d4.channel_uses_per_bfc_decision == 8);
assert(abs(d4.ldpc_payload_rate - 1/2) < 1e-12);
assert(abs(d4.noiseless_bfc_rate - log2(6)/4) < 1e-12);
assert(abs(d4.parallel_bfc_rate - log2(6)/8) < 1e-12);
rates = noisy_channel_rate_metadata(d4, 'id');
assert(abs(rates.parallel_bfc_rate-d4.parallel_bfc_rate) < 1e-12);

e2_configs = noisy_channel_tradeoff_configs( ...
    'e2', 'local_smoke', 'id', [0.05 0.10]);
assert(numel(e2_configs) == 2);
assert(e2_configs{1}.ldpc.rate == 1/2);
assert(e2_configs{1}.bfc.E2 ~= e2_configs{2}.bfc.E2);

rate_configs = noisy_channel_tradeoff_configs( ...
    'ldpc_rate', 'local_smoke', 'id', [1/3 1/2 2/3]);
rate_derived = cellfun(@(x) derive_bfc_parameters(x, 4), ...
    rate_configs, 'UniformOutput', false);
assert(all(cellfun(@(x) x.K, rate_derived) == rate_derived{1}.K));
assert(issorted(cellfun( ...
    @(x) x.channel_uses_per_bfc_decision, rate_derived), 'descend'));
fprintf('PASS: rate bookkeeping and tradeoff configurations\n');

%% Uncoded channel checks against analytical BPSK BER
num_bits = 2e5;
bits = rand(num_bits, 1) > 0.5;
ebno_db = 4;
gamma = 10^(ebno_db/10);
llr_awgn = transmit_bpsk_llr(bits, 'awgn', ebno_db, 1);
ber_awgn = mean((llr_awgn < 0) ~= bits);
theory_awgn = 0.5*erfc(sqrt(gamma));
assert(abs(ber_awgn-theory_awgn) < 0.003);

llr_rayleigh = transmit_bpsk_llr(bits, 'rayleigh', ebno_db, 1);
ber_rayleigh = mean((llr_rayleigh < 0) ~= bits);
theory_rayleigh = 0.5*(1-sqrt(gamma/(1+gamma)));
assert(abs(ber_rayleigh-theory_rayleigh) < 0.005);
fprintf('PASS: AWGN and Rayleigh BPSK models\n');

%% One-frame end-to-end concatenated-code smoke test
cfg = noisy_channel_config('local_smoke');
cfg.channel_types = {'awgn'};
cfg.ebno_db = 20;
cfg.mc.min_frames = 1;
cfg.mc.max_frames = 1;
cfg.mc.target_ldpc_frame_errors = 1;
bank = prepare_bfc_source_bank(cfg, cfg.n_list(1));
assert(all(bank.noiseless_f(bank.actual_f)));
result = run_noisy_channel_point(cfg, bank, 'awgn', 20);
assert(result.complete);
assert(result.frames == 1);
assert(result.metrics.ldpc_payload_ber == 0);
assert(result.metrics.coded_tuple_error_rate == 0);
fprintf('PASS: one-frame LDPC/BFC end-to-end simulation\n');

fprintf('=== ALL NOISY-CHANNEL TESTS PASSED ===\n');
