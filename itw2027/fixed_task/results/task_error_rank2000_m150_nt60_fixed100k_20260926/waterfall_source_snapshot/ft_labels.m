function labels = ft_labels(bits,d,target)
assert(size(bits,2)==d.m);
switch d.family
    case 'id', labels=all(bits==target,2);
    case 'rank'
        width=max(1,ceil(log2(double(d.rank_threshold)+1)));
        weights=2.^((width-1):-1:0).';
        tail=double(bits(:,end-width+1:end))*weights;
        if width<d.m
            leading_zero=~any(bits(:,1:end-width),2);
        else
            leading_zero=true(size(bits,1),1);
        end
        labels=leading_zero & tail<=d.rank_threshold;
    case 'exact', labels=sum(bits,2)==2;
end
end
