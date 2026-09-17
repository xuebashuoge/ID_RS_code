function result = ft_noisy(task,out)
d=ft_config(task.family); path=fullfile(out,task.output);
saved=load(fullfile(out,task.bank)); bank=saved.result;
assert(bank.complete && bank.frames_done==task.frames);
assert(strcmp(bank.config.family,task.family));
assert(bank.task.first_frame==task.first_frame && bank.task.seed_group==task.seed_group);
if strcmp(task.scheme,'bfc'), rate=1/3; else
    assert(strcmp(task.scheme,'conventional') && strcmp(task.family,'exact'));
    rate=5/6;
end
enc=ldpcEncoderConfig(dvbs2ldpc(rate)); dec=ldpcDecoderConfig(enc,'bp');
assert(enc.BlockLength==d.Nb);
if isfile(path)
    saved=load(path); result=saved.result; assert(isequal(result.task,task));
    if result.complete, return; end
else
    result=struct('task',task,'config',d,'complete',false,'frames_done',0, ...
        'rate',rate,'snr_definition','Es/N0; real AWGN variance N0/2','runtime_seconds',0);
    result.channel=struct('Nb',enc.BlockLength,'Ni',enc.NumInformationBits, ...
        'Rc',rate,'G',d.G,'algorithm',d.algorithm,'max_iterations',d.max_iterations);
    % Columns: negative, positive, FP, FN, FER, noiseless FP, iterations.
    result.columns={'negative','positive','fp','fn','fer','noiseless_fp','iterations'};
    result.per_frame=zeros(task.frames,7);
end
clock=tic; N0=10^(-task.snr_db/10); labels=bank.positive;
for frame=result.frames_done+1:task.frames
    if strcmp(task.scheme,'bfc')
        info=pack_bfc_tuples(bank.u(:,frame),bank.c(:,frame),d.r,enc.NumInformationBits,d.G);
    else
        info=reshape(bank.messages(:,:,frame).',[],1);
    end
    assert(numel(info)==enc.NumInformationBits);
    coded=ldpcEncode(info,enc);
    seed=task.seed_group*10000000+d.family_id*1000000+ ...
        task.snr_index*10000+task.first_frame+frame-1;
    stream=RandStream('mt19937ar','Seed',seed);
    rx=1-2*double(coded)+sqrt(N0/2)*randn(stream,size(coded));
    [decoded,iterations]=ldpcDecode(4*rx/N0,dec,d.max_iterations, ...
        'OutputFormat','info','DecisionType','hard','Termination','early','Multithreaded',true);
    decoded=logical(decoded);
    if strcmp(task.scheme,'bfc')
        [u,c]=unpack_bfc_tuples(decoded,d.r);
        f=bank.noiseless(:,frame);
        changed=u~=bank.u(:,frame) | c~=bank.c(:,frame);
        f(changed)=decode_bfc_tuples_vec(u(changed),c(changed),bank.support, ...
            d.r,d.K,d.T,d.memory,'extended');
        reference=sum(~labels & bank.noiseless(:,frame));
    else
        messages=reshape(decoded,d.m,d.G).';
        f=ft_labels(messages,d,[]); reference=0;
    end
    result.per_frame(frame,:)=[sum(~labels),sum(labels),sum(f & ~labels), ...
        sum(~f & labels),any(decoded~=info),reference,iterations];
    result.frames_done=frame;
    if mod(frame,10)==0 || frame==task.frames
        ft_save(path,result);
        fprintf('%s %s SNR %.2f frame %d/%d %.1fs\n',task.family,task.scheme,task.snr_db,frame,task.frames,toc(clock));
    end
    if toc(clock)>task.runtime_limit, break; end
end
result.runtime_seconds=result.runtime_seconds+toc(clock);
totals=sum(result.per_frame(1:result.frames_done,:),1);
result.counts=struct('negative_trials',totals(1),'positive_trials',totals(2), ...
    'false_positives',totals(3),'false_negatives',totals(4), ...
    'frame_errors',totals(5),'frames',result.frames_done,'noiseless_false_positives',totals(6));
result.metrics=struct('FP',totals(3)/totals(1),'FN',totals(4)/totals(2), ...
    'FER',totals(5)/result.frames_done,'noiseless_FP',totals(6)/totals(1));
result.complete=result.frames_done==task.frames; ft_save(path,result);
assert(result.complete,'FT:Incomplete','Channel checkpointed; resubmit this task.');
end
