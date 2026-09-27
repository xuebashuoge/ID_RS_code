function [symbols,bits] = ft_sample(d,support_bits,labels,seed)
% Per-frame seeds make banks reproducible across schemes and SNRs.
stream=RandStream('mt19937ar','Seed',seed);
n=numel(labels); bits=false(n,d.m);
positive=find(labels); negative=find(~labels);
bits(positive,:)=support_bits(randi(stream,d.S,numel(positive),1),:);
while ~isempty(negative)
    candidates=rand(stream,numel(negative),d.m)>0.5;
    accepted=~ft_labels(candidates,d,support_bits(1,:));
    bits(negative(accepted),:)=candidates(accepted,:);
    negative=negative(~accepted);
end
symbols=bits_to_symbols_uint32([bits false(n,d.pad)],d.r);
end
