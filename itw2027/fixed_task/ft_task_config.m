function d=ft_task_config(task)
% Legacy manifests retain their original nt=40,G=540 defaults.
nt=40; G=540;
if isfield(task,'nt'), nt=task.nt; end
if isfield(task,'G'), G=task.G; end
d=ft_config(task.family,nt,G);
assert(d.Ni==21600,'The noisy campaign uses the existing rate-1/3 BFC code.');
end
