function decoded = decode_received_bfc(u_hat, c_hat, u_sent, c_sent, noiseless_decoded, bank, memory_cfg)
%DECODE_RECEIVED_BFC Reuse noiseless decisions for unchanged received tuples.

    u_hat = uint32(u_hat(:));
    c_hat = uint32(c_hat(:));
    u_sent = uint32(u_sent(:));
    c_sent = uint32(c_sent(:));
    decoded = logical(noiseless_decoded(:));

    changed = (u_hat ~= u_sent) | (c_hat ~= c_sent);
    if any(changed)
        decoded(changed) = decode_bfc_tuples_vec( ...
            u_hat(changed), c_hat(changed), bank.valid_symbols, ...
            bank.metadata.r, bank.metadata.K, bank.metadata.L, memory_cfg, ...
            bank.metadata.rs_length_mode);
    end
end
