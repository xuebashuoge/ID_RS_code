function test_task_comparison()
ft_setup(); out=tempname; mkdir(out); cleanup=onCleanup(@() rmdir(out,'s'));
d=ft_config('rank',60,360,struct('m',150,'rank_threshold',2000));
[~,bits]=ft_support(d);
assert(d.S==2001 && d.K==5 && all(ft_labels(bits,d,[])));
bad=bits(end,:); bad(end)=true; % 2001 is outside the support.
assert(~ft_labels(bad,d,[]));
bad=bits(1,:); bad(1)=true; assert(~ft_labels(bad,d,[]));
for mode=1:3
    t=struct('kind','task_comparison','family','rank','scheme','conventional', ...
        'm',150,'rank_threshold',2000,'ldpc_rate',5/6,'nt',60,'G',360, ...
        'frames_per_point',1000000,'source_seed',20261001, ...
        'position_seed',20261002,'noise_seed',20261003,'snr_db',-8, ...
        'snr_index',7,'frames',2,'first_frame',1,'runtime_limit',600, ...
        'output',sprintf('whole%d.mat',mode));
    if mode==2, t.family='exact'; t.m=100; t.ldpc_rate=3/5; end
    if mode==3, t.scheme='bfc'; t.ldpc_rate=1/3; end
    whole=ft_task_comparison(t,out);
    assert(whole.counts.information_frame_errors==2 && whole.counts.false_negatives>0);
    assert(whole.metrics.balanced_error<whole.metrics.information_FER);
    a=t; a.frames=1; a.output=sprintf('part%d_a.mat',mode);
    part1=ft_task_comparison(a,out);
    a.first_frame=2; a.output=sprintf('part%d_b.mat',mode);
    part2=ft_task_comparison(a,out);
    assert(isequal(whole.per_frame,[part1.per_frame;part2.per_frame]));
    r=t; r.output=sprintf('resume%d.mat',mode); r.runtime_limit=0;
    try
        ft_task_comparison(r,out); error('Test:ExpectedIncomplete','Expected checkpoint');
    catch err
        assert(strcmp(err.identifier,'FT:Incomplete'));
    end
    resumed=ft_task_comparison(r,out);
    assert(isequal(whole.per_frame,resumed.per_frame));
    h=t; h.snr_db=15; h.output=sprintf('high%d.mat',mode);
    high=ft_task_comparison(h,out);
    assert(high.counts.information_frame_errors==0 && high.counts.false_negatives==0);
    if mode~=3, assert(high.metrics.balanced_error==0); end
end
fprintf('Task labels, task error versus FER, shard equivalence and resume passed.\n');
end
