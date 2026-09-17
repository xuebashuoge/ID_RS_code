function d = ft_config(family, nt)
if nargin < 2, nt = 40; end
assert(ismember(family, {'id','rank','exact'}));
assert(mod(nt,2)==0 && nt>=4 && nt<=64);
d.version = 1; d.family = family; d.nt = nt;
switch family
    case 'id', d.m=100000; d.S=1; d.family_id=1;
    case 'rank', d.m=5000; d.S=21; d.family_id=2;
    case 'exact', d.m=100; d.S=nchoosek(d.m,2); d.family_id=3;
end
d.r=nt/2; d.T=2^d.r; d.K=ceil(d.m/d.r);
assert(d.K<=d.T);
d.pad=d.r*d.K-d.m;
d.bound=min(1,d.S*(d.K-1)/d.T);
d.G=540; d.Nb=64800; d.Ni=d.G*nt;
d.Rc=d.Ni/d.Nb; d.neff=d.Nb/d.G;
d.algorithm='bp'; d.max_iterations=50;
d.memory.region_working_mb=128;
end
