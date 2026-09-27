function result=ft_conventional_full(task,out)
% Stream fresh exact-threshold messages; no repeated banks or RS computation.
d=ft_config('exact',60,360);
assert(strcmp(task.kind,'conventional_full') && task.ldpc_rate==3/5);
assert(task.first_frame>=1 && task.first_frame+task.frames-1<=task.frames_per_point);
assert(task.frames_per_point<2^32 && task.snr_index>=1 && task.snr_index<2^20);
enc=ldpcEncoderConfig(dvbs2ldpc(task.ldpc_rate)); dec=ldpcDecoderConfig(enc,'bp');
payload=d.m*d.G; assert(enc.NumInformationBits==38880 && payload==36000);
[~,support]=ft_support(d); labels=mod((1:d.G)',2)==1;
source=RandStream('Threefry','Seed',task.source_seed);
noise=RandStream('Threefry','Seed',task.noise_seed);
path=fullfile(out,task.output);
if isfile(path)
    saved=load(path); result=saved.result; assert(isequal(result.task,task));
    if result.complete, return; end
else
    result=struct('task',task,'config',d,'complete',false,'frames_done',0, ...
        'runtime_seconds',0,'rate',task.ldpc_rate, ...
        'snr_definition','Es/N0; real AWGN variance N0/2', ...
        'source_sampling','Independent Threefry substream per fresh frame; shared across SNRs', ...
        'noise_sampling','Threefry substream snr_index*2^32+global_frame');
    result.channel=struct('Nb',64800,'Ni',38880,'Rc',3/5,'G',360, ...
        'payload_bits',payload,'padding_bits',2880,'algorithm','bp','max_iterations',50);
    result.columns={'negative','positive','fp','fn','fer','noiseless_fp','iterations'};
    result.per_frame=zeros(task.frames,7,'uint32');
end
previous_runtime=result.runtime_seconds; timer=tic; N0=10^(-task.snr_db/10);
for frame=result.frames_done+1:task.frames
    global_frame=task.first_frame+frame-1;
    source.Substream=global_frame;
    noise.Substream=task.snr_index*2^32+global_frame;
    messages=false(d.G,d.m);
    messages(labels,:)=support(randi(source,d.S,d.G/2,1),:);
    remaining=find(~labels);
    while ~isempty(remaining)
        proposals=rand(source,numel(remaining),d.m)>.5;
        accepted=sum(proposals,2)~=2;
        messages(remaining(accepted),:)=proposals(accepted,:);
        remaining=remaining(~accepted);
    end
    info=false(enc.NumInformationBits,1);
    info(1:payload)=reshape(messages.',[],1);
    encoded=ldpcEncode(info,enc);
    rx=1-2*double(encoded)+sqrt(N0/2)*randn(noise,size(encoded));
    [decoded,iterations]=ldpcDecode(4*rx/N0,dec,50,'OutputFormat','info', ...
        'DecisionType','hard','Termination','early','Multithreaded',true);
    decoded=logical(decoded);
    estimated=sum(reshape(decoded(1:payload),d.m,d.G),1)'==2;
    result.per_frame(frame,:)=uint32([180,180,sum(estimated & ~labels), ...
        sum(~estimated & labels),any(decoded~=info),0,iterations]);
    result.frames_done=frame;
    if mod(frame,100)==0 || frame==task.frames || toc(timer)>task.runtime_limit
        result=finish_counts(result,previous_runtime+toc(timer));
        ft_save(path,result);
        fprintf('Rc=3/5 SNR %.2f frames %d/%d global %d FER %.7g elapsed %.1fs\n', ...
            task.snr_db,frame,task.frames,global_frame,result.metrics.FER,toc(timer));
    end
    if toc(timer)>task.runtime_limit, break; end
end
result=finish_counts(result,previous_runtime+toc(timer)); ft_save(path,result);
assert(result.complete,'FT:Incomplete','Checkpoint saved; resume this same manifest index.');
end

function result=finish_counts(result,runtime)
totals=sum(double(result.per_frame(1:result.frames_done,:)),1);
result.runtime_seconds=runtime;
result.counts=struct('negative_trials',totals(1),'positive_trials',totals(2), ...
    'false_positives',totals(3),'false_negatives',totals(4), ...
    'frame_errors',totals(5),'frames',result.frames_done);
result.metrics=struct('FP',totals(3)/totals(1),'FN',totals(4)/totals(2), ...
    'FER',totals(5)/result.frames_done, ...
    'balanced_error',(totals(3)+totals(4))/(totals(1)+totals(2)));
result.complete=result.frames_done==result.task.frames;
end
