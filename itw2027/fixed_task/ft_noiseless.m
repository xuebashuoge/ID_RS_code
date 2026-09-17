function result = ft_noiseless(task,out)
d=ft_config(task.family,task.nt); [support,support_bits]=ft_support(d);
first_position=1;
if isfield(task,'first_position'), first_position=task.first_position; end
% Same original messages at every nt; per-message seeds independent of nt.
negative=zeros(task.messages,d.K,'uint32');
for j=1:task.messages
    seed=50000000+task.seed_group*1000000+d.family_id*100000+task.first_message+j-1;
    negative(j,:)=ft_sample(d,support_bits,false,seed);
end
path=fullfile(out,task.output);
if isfile(path)
    saved=load(path); result=saved.result; assert(isequal(result.task,task));
    if result.complete, return; end
else
    result=struct('task',task,'config',d,'complete',false,'next_position',first_position, ...
        'hits',zeros(task.messages,1),'runtime_seconds',0);
end
clock=tic; prim=get_primpoly(d.r); stop=min(d.T,task.positions);
for first=result.next_position:task.chunk_size:stop
    indices=first:min(first+task.chunk_size-1,stop);
    x=rs_evaluation_points_at(d.r,uint32(indices),prim,'extended');
    valid=evaluate_symbol_polynomials(support,x,d.r,prim);
    values=evaluate_symbol_polynomials(negative,x,d.r,prim);
    for j=1:numel(indices)
        result.hits=result.hits+ismember(values(:,j),valid(:,j));
    end
    result.next_position=indices(end)+1;
    ft_save(path,result);
    fprintf('%s nt %d positions %d/%d %.1fs\n',task.family,task.nt,indices(end),stop,toc(clock));
    if toc(clock)>task.runtime_limit, break; end
end
result.runtime_seconds=result.runtime_seconds+toc(clock);
result.complete=result.next_position>stop;
result.full_enumeration=first_position==1 && stop==d.T;
result.probabilities=result.hits/(result.next_position-first_position);
result.counts=struct('false_positives_per_message',result.hits, ...
    'negative_trials_per_message',result.next_position-first_position);
result.metrics=struct('FP_per_message',result.probabilities,'FN',0);
result.fn_basis='Analytically zero by construction; no positive Monte Carlo trials claimed';
ft_save(path,result);
assert(result.complete,'FT:Incomplete','Noiseless checkpointed; resubmit this task.');
end
