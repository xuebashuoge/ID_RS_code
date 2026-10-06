function test_bfc_100k()
ft_setup(); out=tempname; mkdir(out); cleanup=onCleanup(@() rmdir(out,'s'));
for family={'id','exact'}
    name=family{1};
    if strcmp(name,'id'), m=100000; else, m=100; end
    task=struct('kind','task_comparison','family',name,'scheme','bfc', ...
        'm',m,'ldpc_rate',1/3,'nt',60,'G',360,'frames_per_point',100000, ...
        'source_seed',20261006,'position_seed',20261007,'noise_seed',20261008, ...
        'snr_db',-5,'snr_index',1,'frames',1,'first_frame',1, ...
        'runtime_limit',900,'output',[name '.mat']);
    result=ft_task_comparison(task,out);
    assert(result.complete && result.frames_done==1);
    assert(result.counts.negative_trials==180 && result.counts.positive_trials==180);
    assert(result.channel.Rc==1/3 && result.channel.payload_bits==21600);
    resumed=ft_task_comparison(task,out);
    assert(isequal(result.per_frame,resumed.per_frame));
end
fprintf('ID and exact-weight BFC 100,000-frame manifest smoke passed.\n');
end
