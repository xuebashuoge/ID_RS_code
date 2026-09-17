function test_fixed_task()
ft_setup();
for family={'id','rank','exact'}
    d=ft_config(family{1},28); [support,bits]=ft_support(d);
    assert(size(support,1)==d.S && size(bits,2)==d.m);
    assert(all(ft_labels(bits,d,bits(1,:))));
    if d.pad>0, assert(all(bitand(support(:,end),uint32(2^d.pad-1))==0)); end
    [negative,original]=ft_sample(d,bits,false(3,1),819);
    assert(~any(ft_labels(original,d,bits(1,:))));
    d40=ft_config(family{1},40); [~,bits40]=ft_support(d40);
    [~,original40]=ft_sample(d40,bits40,false(3,1),819);
    assert(isequal(original,original40));
    u=uint32([1;17;d.T]); prim=get_primpoly(d.r);
    x=rs_evaluation_points_at(d.r,u,prim,'extended');
    c=evaluate_rs_positions_vec(support(ones(3,1),:),x,d.r,prim);
    assert(all(decode_bfc_tuples_vec(u,c,support,d.r,d.K,d.T,d.memory,'extended')));
    packed=pack_bfc_tuples(u,c,d.r,3*d.nt,3); [u2,c2]=unpack_bfc_tuples(packed,d.r);
    assert(isequal(u,u2) && isequal(c,c2));
    assert(size(negative,2)==d.K);
end
% Independent brute-force reference in a small, padded source space.
d=ft_config('exact',28); d.m=7; d.r=3; d.nt=6; d.K=3; d.pad=2; d.T=8; d.S=21;
[support,~]=ft_support(d); allbits=false(128,7);
for j=1:7, allbits(:,j)=bitget(uint32((0:127)'),8-j)>0; end
coeff=bits_to_symbols_uint32([allbits false(128,2)],3); prim=get_primpoly(3);
for u=1:8
    x=rs_evaluation_points_at(3,uint32(u),prim,'extended');
    tags=evaluate_rs_positions_vec(coeff,x,3,prim);
    direct=ismember(tags,tags(sum(allbits,2)==2));
    decoded=decode_bfc_tuples_vec(repmat(uint32(u),128,1),tags,support,3,3,8,d.memory,'extended');
    assert(isequal(direct,decoded));
end
% Full BFC and conventional LDPC round trips at high SNR, plus resume.
out=tempname; mkdir(out); cleanup=onCleanup(@() rmdir(out,'s'));
task=struct('kind','bank','family','exact','frames',2,'first_frame',1, ...
    'seed_group',9,'output','bank.mat','runtime_limit',600);
ft_bank(task,out);
for scheme={'bfc','conventional'}
    noisy=struct('kind','noisy','family','exact','scheme',scheme{1},'frames',2, ...
        'first_frame',1,'seed_group',9,'snr_db',15,'snr_index',1, ...
        'bank','bank.mat','output',[scheme{1} '.mat'],'runtime_limit',600);
    result=ft_noisy(noisy,out);
    assert(all(result.per_frame(:,4:5)==0,'all'));
    assert(all(result.per_frame(:,3)==result.per_frame(:,6)));
    assert(result.metrics.FN==0 && result.metrics.FER==0);
    assert(result.counts.negative_trials==540 && result.counts.positive_trials==540);
    assert(result.counts.false_positives==sum(result.per_frame(:,3)));
    again=ft_noisy(noisy,out); assert(isequal(result,again));
end
% Exercise each family on a failing channel and verify resumable checkpoints.
for family={'id','rank','exact'}
    task=struct('kind','bank','family',family{1},'frames',2,'first_frame',5, ...
        'seed_group',9,'output',['resume_' family{1} '.mat'],'runtime_limit',0);
    try
        ft_bank(task,out); error('Test:ExpectedCheckpoint','Expected an incomplete checkpoint');
    catch err
        assert(strcmp(err.identifier,'FT:Incomplete'));
    end
    bank=ft_bank(task,out); assert(bank.complete && bank.frames_done==2);
    noisy=struct('kind','noisy','family',family{1},'scheme','bfc','frames',2, ...
        'first_frame',5,'seed_group',9,'snr_db',-8,'snr_index',2, ...
        'bank',task.output,'output',['low_' family{1} '.mat'],'runtime_limit',600);
    result=ft_noisy(noisy,out);
    assert(all(result.per_frame(:,5)==1));
    assert(sum(result.per_frame(:,4))>0);
end
fprintf('Fixed-task tests passed.\n');
% Position sharding must exactly reproduce an unsplit enumeration.
task=struct('kind','noiseless','family','exact','nt',28,'messages',3, ...
    'first_message',1,'seed_group',9,'first_position',1,'positions',128, ...
    'chunk_size',64,'runtime_limit',600,'output','whole.mat');
whole=ft_noiseless(task,out);
task.positions=64; task.output='part1.mat'; part1=ft_noiseless(task,out);
task.first_position=65; task.positions=128; task.output='part2.mat'; part2=ft_noiseless(task,out);
assert(isequal(whole.hits,part1.hits+part2.hits));
fprintf('Position-shard equivalence passed.\n');
end
