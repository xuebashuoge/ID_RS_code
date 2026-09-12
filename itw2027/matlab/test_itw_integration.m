function test_itw_integration()
root=fileparts(fileparts(mfilename('fullpath'))); repo=fileparts(root);
old=pwd;oldpath=path;cleanup=onCleanup(@()restore(old,oldpath)); %#ok<NASGU>
if isfolder(fullfile(root,'results','source','noisy','waterfall'))
    run_itw_noisy('point','waterfall',0);
    run_itw_noisy('point','rate_pareto',59);
end
addpath(repo,fullfile(repo,'conference_simulation'));
test_conference_simulation();
cd(fullfile(root,'matlab','noisy'));addpath(pwd,'-begin');
for j=1:3
    families={'id','rank','exact-threshold'}; ns=[8 16 30];
    cfg=noisy_channel_config('local_smoke');
    cfg.bfc.func_type=families{j}; cfg.n_list=ns(j);cfg.channel_types={'awgn'};
    cfg.ldpc.algorithm='bp';cfg.ldpc.multithreaded=false;
    cfg.mc.stopping_mode='fixed_frames';cfg.mc.max_frames=2;
    cfg.mc.cluster_bootstrap_replicates=20;
    cfg.memory.sample_message_batch=128;
    cfg.memory.frames_per_batch=1;
    cfg.mc.max_runtime_seconds=600;
    bank=prepare_bfc_source_bank(cfg,ns(j),'');
    for ebno=[0 6]
        result=run_noisy_channel_point(cfg,bank,'awgn',ebno,'');
        assert(result.complete && result.frames==2);
        pf=result.per_frame;
        assert(all(double(pf.coded_false_negative)<=double(pf.actual_one).*double(pf.ldpc_error)));
        assert(all(double(pf.coded_false_positive)<=double(pf.noiseless_false_positive)+double(pf.actual_zero).*double(pf.ldpc_error)));
        if ebno==6, assert(~any(pf.ldpc_error)); end
    end
end
fprintf('ITW2027: noiseless exact enumeration and six packed BP smoke points passed.\n');
end
function restore(folder,oldpath)
cd(folder);path(oldpath);
end
