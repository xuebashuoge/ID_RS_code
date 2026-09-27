function ft_run(manifest,index,out)
ft_setup();
tasks=jsondecode(fileread(manifest));
% Mixed rank/exact manifests have different fields and decode as cell arrays.
if iscell(tasks), task=tasks{index+1}; else, task=tasks(index+1); end
fprintf('Task %d: %s\n',index,jsonencode(task));
switch task.kind
    case 'conventional_full', ft_conventional_full(task,out);
    case 'task_comparison', ft_task_comparison(task,out);
    case 'bank', ft_bank(task,out);
    case 'noisy', ft_noisy(task,out);
    case 'noiseless', ft_noiseless(task,out);
    otherwise, error('Unknown task kind');
end
end
