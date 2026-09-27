function d = ft_config(family, nt, G, params)
if nargin < 2, nt = 40; end
if nargin < 3, G = 540; end
if nargin < 4, params = struct(); end
assert(G>0 && mod(G,2)==0);
assert(ismember(family, {'id','rank','exact'}));
assert(mod(nt,2)==0 && nt>=4 && nt<=64);
d.version = 1; d.family = family; d.nt = nt;
switch family
    case 'id'
        d.m=100000; d.S=1; d.family_id=1;
    case 'rank'
        d.m=5000; d.rank_threshold=20; d.family_id=2;
        if isfield(params,'m'), d.m=params.m; end
        if isfield(params,'rank_threshold'), d.rank_threshold=params.rank_threshold; end
        assert(d.m==floor(d.m) && d.m>=1);
        assert(d.rank_threshold==floor(d.rank_threshold) && d.rank_threshold>=0);
        assert(log2(double(d.rank_threshold)+1)<=d.m, ...
            'The rank threshold must fit in the m-bit source alphabet.');
        d.S=d.rank_threshold+1;
    case 'exact'
        d.m=100; d.family_id=3;
        if isfield(params,'m'), d.m=params.m; end
        assert(d.m==floor(d.m) && d.m>=2);
        d.S=nchoosek(d.m,2);
end
d.r=nt/2; d.T=2^d.r; d.K=ceil(d.m/d.r);
assert(d.K<=d.T);
d.pad=d.r*d.K-d.m;
d.bound=min(1,d.S*(d.K-1)/d.T);
d.G=G; d.Nb=64800; d.Ni=d.G*nt;
d.Rc=d.Ni/d.Nb; d.neff=d.Nb/d.G;
d.algorithm='bp'; d.max_iterations=50;
d.memory.region_working_mb=128;
end
