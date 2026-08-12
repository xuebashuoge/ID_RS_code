function rates = noisy_channel_rate_metadata(value, func_type)
%NOISY_CHANNEL_RATE_METADATA Return unambiguous BFC/channel rate metrics.
%
%   RATES = NOISY_CHANNEL_RATE_METADATA(RESULT) accepts a saved result.
%   RATES = NOISY_CHANNEL_RATE_METADATA(DERIVED, FUNC_TYPE) accepts the
%   derived-parameter structure directly. The fallback calculations make
%   this helper compatible with result files created before these fields
%   were saved explicitly.

    if isfield(value, 'derived')
        d = value.derived;
        if nargin < 2
            if isfield(value, 'bank_metadata') && ...
                    isfield(value.bank_metadata, 'func_type')
                func_type = value.bank_metadata.func_type;
            elseif isfield(value, 'config') && isfield(value.config, 'bfc')
                func_type = value.config.bfc.func_type;
            else
                error('The saved result does not identify its Boolean function type.');
            end
        end
    else
        d = value;
        if nargin < 2
            error('FUNC_TYPE is required when passing a derived structure.');
        end
    end

    rates.ldpc_code_rate = d.ldpc_K / d.ldpc_N;
    rates.ldpc_payload_rate = d.payload_bits_per_frame / d.ldpc_N;
    rates.padding_efficiency = d.payload_bits_per_frame / d.ldpc_K;
    rates.channel_uses_per_bfc_decision = d.ldpc_N / d.tuples_per_frame;

    if isfield(d, 'noiseless_bfc_rate')
        rates.noiseless_bfc_rate = d.noiseless_bfc_rate;
    else
        rates.noiseless_bfc_rate = rate_calculation(d.n, d.m, func_type);
    end

    if isfield(d, 'parallel_bfc_rate')
        rates.parallel_bfc_rate = d.parallel_bfc_rate;
    else
        rate_numerator = d.n * rates.noiseless_bfc_rate;
        rates.parallel_bfc_rate = ...
            d.tuples_per_frame * rate_numerator / d.ldpc_N;
    end
end
