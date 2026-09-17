function labels = ft_labels(bits,d,target)
assert(size(bits,2)==d.m);
switch d.family
    case 'id', labels=all(bits==target,2);
    case 'rank'
        tail=double(bits(:,end-4:end))*[16;8;4;2;1];
        labels=~any(bits(:,1:end-5),2) & tail<=20;
    case 'exact', labels=sum(bits,2)==2;
end
end
