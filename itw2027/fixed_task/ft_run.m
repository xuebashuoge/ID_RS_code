function ft_run(manifest,index,out)
ft_setup();
tasks=jsondecode(fileread(manifest)); task=tasks(index+1);
fprintf('Task %d: %s\n',index,jsonencode(task));
switch task.kind
    case 'bank', ft_bank(task,out);
    case 'noisy', ft_noisy(task,out);
    case 'noiseless', ft_noiseless(task,out);
    otherwise, error('Unknown task kind');
end
end
