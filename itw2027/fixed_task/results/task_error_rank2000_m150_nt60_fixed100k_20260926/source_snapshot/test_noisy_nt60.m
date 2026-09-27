function test_noisy_nt60()
ft_setup(); out=tempname; mkdir(out); cleanup=onCleanup(@() rmdir(out,'s'));
for family={'id','rank','exact'}
    task=struct('kind','bank','family',family{1},'nt',60,'G',360, ...
        'frames',2,'first_frame',1,'seed_group',3,'runtime_limit',600, ...
        'output',[family{1} '_n_t_60.mat']);
    bank=ft_bank(task,out); d=bank.config;
    assert(d.r==30 && d.T==2^30 && d.G==360 && d.neff==180 && d.Ni==21600);
    assert(d.m+d.pad==d.K*d.r);
    assert(size(bank.u,1)==360 && sum(bank.positive)==180);
    % Ensure uint32 packing preserves the entire 30-bit index/tag range.
    u=uint32([1;2^30]); c=uint32([0;2^30-1]);
    payload=pack_bfc_tuples(u,c,30,120,2); [ur,cr]=unpack_bfc_tuples(payload,30);
    assert(isequal(u,ur) && isequal(c,cr));
    for snr=[-8 15]
        noisy=struct('kind','noisy','family',family{1},'scheme','bfc','nt',60,'G',360, ...
            'frames',2,'first_frame',1,'seed_group',3,'snr_db',snr,'snr_index',1, ...
            'bank',task.output,'output',sprintf('%s_%d_n_t_60.mat',family{1},snr),'runtime_limit',600);
        result=ft_noisy(noisy,out);
        assert(result.counts.positive_trials==360 && result.counts.negative_trials==360);
        if snr==15
            assert(result.metrics.FN==0 && result.metrics.FER==0);
            assert(result.counts.false_positives==result.counts.noiseless_false_positives);
        else
            assert(result.metrics.FER==1 && result.counts.false_negatives>0);
        end
    end
    if strcmp(family{1},'exact')
        noisy.scheme='conventional'; noisy.output='conventional_n_t_60.mat';
        noisy.ldpc_rate=3/5;
        result=ft_noisy(noisy,out);
        assert(result.channel.Ni==38880 && result.channel.Rc==3/5);
        assert(result.channel.padding_bits==2880 && result.channel.payload_bits==36000);
        assert(result.metrics.FER==0 && result.metrics.FN==0 && result.metrics.FP==0);
        noisy.snr_db=-8; noisy.output='conventional_low_n_t_60.mat';
        result=ft_noisy(noisy,out); assert(result.metrics.FER==1 && result.metrics.FN>0);
    end
end
legacy=ft_config('id'); assert(legacy.G==540); % Old default remains unchanged.
fprintf('Noisy-only nt=60 tests passed.\n');
end
