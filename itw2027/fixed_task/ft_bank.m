function result = ft_bank(task,out)
d=ft_config(task.family); [support,support_bits]=ft_support(d);
path=fullfile(out,task.output);
signature=task;
if isfile(path)
    saved=load(path); result=saved.result;
    assert(isequal(result.task,signature));
    if result.complete, return; end
else
    result=struct('task',signature,'config',d,'complete',false,'frames_done',0);
    result.u=zeros(d.G,task.frames,'uint32'); result.c=result.u;
    result.noiseless=false(d.G,task.frames);
    result.positive=mod((1:d.G)',2)==1;
    result.support=support;
    if strcmp(d.family,'exact'), result.messages=false(d.G,d.m,task.frames); end
    result.runtime_seconds=0;
end
clock=tic; prim=get_primpoly(d.r);
for frame=result.frames_done+1:task.frames
    global_frame=task.first_frame+frame-1;
    seed=1000000*task.seed_group+100000*d.family_id+global_frame;
    [symbols,bits]=ft_sample(d,support_bits,result.positive,seed);
    stream=RandStream('mt19937ar','Seed',seed+10000000);
    u=uint32(randi(stream,d.T,d.G,1));
    x=rs_evaluation_points_at(d.r,u,prim,'extended');
    c=evaluate_rs_positions_vec(symbols,x,d.r,prim);
    f=decode_bfc_tuples_vec(u,c,support,d.r,d.K,d.T,d.memory,'extended');
    assert(all(f(result.positive)));
    result.u(:,frame)=u; result.c(:,frame)=c; result.noiseless(:,frame)=f;
    if strcmp(d.family,'exact'), result.messages(:,:,frame)=bits; end
    result.frames_done=frame;
    if mod(frame,5)==0 || frame==task.frames
        ft_save(path,result); fprintf('bank %s frame %d/%d %.1fs\n',d.family,frame,task.frames,toc(clock));
    end
    if toc(clock)>task.runtime_limit, break; end
end
result.runtime_seconds=result.runtime_seconds+toc(clock);
result.complete=result.frames_done==task.frames; ft_save(path,result);
assert(result.complete,'FT:Incomplete','Bank checkpointed; resubmit this task.');
end
