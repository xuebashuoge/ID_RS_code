function result=ft_task_comparison(task,out)
% Stream fresh ID/rank/exact messages for task-error BFC/conventional comparison.
assert(strcmp(task.kind,'task_comparison'));
assert(task.nt==60 && task.G==360);
assert(ismember(task.family,{'id','rank','exact'}));
assert(ismember(task.scheme,{'bfc','conventional'}));
params=struct('m',task.m);
if strcmp(task.family,'rank'), params.rank_threshold=task.rank_threshold; end
d=ft_config(task.family,task.nt,task.G,params);
assert(task.first_frame>=1 && task.first_frame+task.frames-1<=task.frames_per_point);
assert(task.frames_per_point<2^32 && task.snr_index>=1 && task.snr_index<2^20);
enc=ldpcEncoderConfig(dvbs2ldpc(task.ldpc_rate));
dec=ldpcDecoderConfig(enc,'bp');
assert(enc.BlockLength==64800);
if strcmp(task.scheme,'bfc')
    assert(abs(task.ldpc_rate-1/3)<1e-12);
    payload=d.G*d.nt;
else
    if strcmp(task.family,'rank')
        assert(abs(task.ldpc_rate-5/6)<1e-12);
    else
        assert(strcmp(task.family,'exact'));
        assert(abs(task.ldpc_rate-3/5)<1e-12);
    end
    payload=d.G*d.m;
end
assert(payload<=enc.NumInformationBits);
[support,support_bits]=ft_support(d);
labels=mod((1:d.G)',2)==1;
source=RandStream('Threefry','Seed',task.source_seed);
positions=RandStream('Threefry','Seed',task.position_seed);
noise=RandStream('Threefry','Seed',task.noise_seed);
prim=get_primpoly(d.r);
path=fullfile(out,task.output);
if isfile(path)
    saved=load(path); result=saved.result; assert(isequal(result.task,task));
    if result.complete, return; end
else
    result=struct('task',task,'config',d,'complete',false,'frames_done',0, ...
        'runtime_seconds',0,'rate',task.ldpc_rate, ...
        'snr_definition','Es/N0; real AWGN variance N0/2', ...
        'source_sampling','Fresh Threefry substream per global frame; shared across SNRs and schemes', ...
        'noise_sampling','Threefry substream snr_index*2^32+global_frame');
    result.channel=struct('Nb',enc.BlockLength,'Ni',enc.NumInformationBits, ...
        'Rc',task.ldpc_rate,'G',d.G,'payload_bits',payload, ...
        'padding_bits',enc.NumInformationBits-payload,'algorithm','bp', ...
        'max_iterations',50);
    % Payload FER excludes deterministic padding; information FER includes it.
    result.columns={'negative','positive','fp','fn','payload_fer', ...
        'information_fer','noiseless_fp','iterations'};
    result.per_frame=zeros(task.frames,8,'uint32');
end
previous_runtime=result.runtime_seconds; timer=tic; N0=10^(-task.snr_db/10);
for frame=result.frames_done+1:task.frames
    global_frame=task.first_frame+frame-1;
    source.Substream=global_frame;
    [symbols,messages]=sample_messages(source,d,support_bits,labels);
    if strcmp(task.scheme,'bfc')
        positions.Substream=global_frame;
        u=uint32(randi(positions,d.T,d.G,1));
        x=rs_evaluation_points_at(d.r,u,prim,'extended');
        c=evaluate_rs_positions_vec(symbols,x,d.r,prim);
        noiseless=decode_bfc_tuples_vec(u,c,support,d.r,d.K,d.T,d.memory,'extended');
        assert(all(noiseless(labels)));
        info=pack_bfc_tuples(u,c,d.r,enc.NumInformationBits,d.G);
    else
        noiseless=labels;
        info=false(enc.NumInformationBits,1);
        info(1:payload)=reshape(messages.',[],1);
    end
    encoded=ldpcEncode(info,enc);
    noise.Substream=task.snr_index*2^32+global_frame;
    rx=1-2*double(encoded)+sqrt(N0/2)*randn(noise,size(encoded));
    [decoded,iterations]=ldpcDecode(4*rx/N0,dec,50,'OutputFormat','info', ...
        'DecisionType','hard','Termination','early','Multithreaded',true);
    decoded=logical(decoded);
    if strcmp(task.scheme,'bfc')
        [uhat,chat]=unpack_bfc_tuples(decoded(1:payload),d.r);
        estimated=noiseless;
        changed=uhat~=u | chat~=c;
        estimated(changed)=decode_bfc_tuples_vec(uhat(changed),chat(changed), ...
            support,d.r,d.K,d.T,d.memory,'extended');
    else
        recovered=reshape(decoded(1:payload),d.m,d.G).';
        estimated=ft_labels(recovered,d,[]);
    end
    payload_fer=any(decoded(1:payload)~=info(1:payload));
    information_fer=any(decoded~=info);
    result.per_frame(frame,:)=uint32([sum(~labels),sum(labels), ...
        sum(estimated & ~labels),sum(~estimated & labels),payload_fer, ...
        information_fer,sum(noiseless & ~labels),iterations]);
    result.frames_done=frame;
    if mod(frame,100)==0 || frame==task.frames || toc(timer)>task.runtime_limit
        result=finish_counts(result,previous_runtime+toc(timer));
        ft_save(path,result);
        fprintf('%s %s SNR %.2f frames %d/%d task error %.7g elapsed %.1fs\n', ...
            task.family,task.scheme,task.snr_db,frame,task.frames, ...
            result.metrics.balanced_error,toc(timer));
    end
    if toc(timer)>task.runtime_limit, break; end
end
result=finish_counts(result,previous_runtime+toc(timer)); ft_save(path,result);
assert(result.complete,'FT:Incomplete','Checkpoint saved; resume this same manifest index.');
end

function [symbols,bits]=sample_messages(stream,d,support_bits,labels)
bits=false(d.G,d.m);
positive=find(labels); negative=find(~labels);
bits(positive,:)=support_bits(randi(stream,d.S,numel(positive),1),:);
while ~isempty(negative)
    proposals=rand(stream,numel(negative),d.m)>.5;
    accepted=~ft_labels(proposals,d,support_bits(1,:));
    bits(negative(accepted),:)=proposals(accepted,:);
    negative=negative(~accepted);
end
symbols=bits_to_symbols_uint32([bits false(d.G,d.pad)],d.r);
end

function result=finish_counts(result,runtime)
totals=sum(double(result.per_frame(1:result.frames_done,:)),1);
result.runtime_seconds=runtime;
result.counts=struct('negative_trials',totals(1),'positive_trials',totals(2), ...
    'false_positives',totals(3),'false_negatives',totals(4), ...
    'payload_frame_errors',totals(5),'information_frame_errors',totals(6), ...
    'noiseless_false_positives',totals(7),'frames',result.frames_done);
result.metrics=struct('FP',totals(3)/totals(1),'FN',totals(4)/totals(2), ...
    'payload_FER',totals(5)/result.frames_done, ...
    'information_FER',totals(6)/result.frames_done, ...
    'noiseless_FP',totals(7)/totals(1), ...
    'balanced_error',(totals(3)+totals(4))/(totals(1)+totals(2)));
result.complete=result.frames_done==result.task.frames;
end
