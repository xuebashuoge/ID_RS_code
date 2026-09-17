function [symbols, bits] = ft_support(d)
% The support is defined on m original bits, never on padded bits.
bits=false(d.S,d.m);
switch d.family
    case 'id'
        stream=RandStream('mt19937ar','Seed',73129);
        bits=rand(stream,1,d.m)>0.5;
    case 'rank'
        for j=1:5, bits(:,d.m-5+j)=bitget(uint32((0:20)'),6-j)>0; end
    case 'exact'
        pairs=nchoosek(1:d.m,2); rows=(1:d.S)';
        bits(sub2ind(size(bits),rows,pairs(:,1)))=true;
        bits(sub2ind(size(bits),rows,pairs(:,2)))=true;
end
symbols=bits_to_symbols_uint32([bits false(d.S,d.pad)],d.r);
end
