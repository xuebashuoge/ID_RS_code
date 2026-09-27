function test_conventional_full()
ft_setup(); out=tempname; mkdir(out); cleanup=onCleanup(@() rmdir(out,'s'));
t=struct('kind','conventional_full','family','exact','scheme','conventional', ...
    'ldpc_rate',3/5,'nt',60,'G',360,'frames_per_point',1000000, ...
    'source_seed',20260922,'noise_seed',20260923,'snr_db',-8,'snr_index',7, ...
    'frames',4,'first_frame',1,'runtime_limit',600,'output','whole.mat');
whole=ft_conventional_full(t,out);
assert(whole.counts.frame_errors==4 && whole.counts.false_negatives>0);
a=t; a.frames=2; a.output='part1.mat'; part1=ft_conventional_full(a,out);
a.first_frame=3; a.output='part2.mat'; part2=ft_conventional_full(a,out);
assert(isequal(whole.per_frame,[part1.per_frame;part2.per_frame]));
r=t; r.output='resume.mat'; r.runtime_limit=0;
for k=1:3
    try
        ft_conventional_full(r,out); error('Test:ExpectedIncomplete','Expected incomplete checkpoint');
    catch err
        assert(strcmp(err.identifier,'FT:Incomplete'));
    end
end
resumed=ft_conventional_full(r,out);
assert(isequal(whole.per_frame,resumed.per_frame));
h=t; h.first_frame=999997; h.snr_db=15; h.output='high.mat';
high=ft_conventional_full(h,out);
assert(high.counts.frame_errors==0 && high.counts.false_positives==0 && high.counts.false_negatives==0);
assert(high.counts.positive_trials==720 && high.channel.padding_bits==2880);
% Substreams above 2^32 must be distinct and reconstructable.
s=RandStream('Threefry','Seed',20260923); s.Substream=7*2^32+10000; x=randn(s,8,1);
s.Substream=7*2^32+10001; y=randn(s,8,1); assert(~isequal(x,y));
s.Substream=7*2^32+10000; assert(isequal(x,randn(s,8,1)));
fprintf('Million-frame streaming, shard equivalence and resume checks passed.\n');
end
