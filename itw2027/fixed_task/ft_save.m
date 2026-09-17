function ft_save(path,result)
parent=fileparts(path); if ~isfolder(parent), mkdir(parent); end
temporary=[tempname(parent) '.mat'];
save(temporary,'result','-v7');
movefile(temporary,path,'f');
end
