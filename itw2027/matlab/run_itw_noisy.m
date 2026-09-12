function run_itw_noisy(mode, experiment, task_id)
% ITW2027 entry point. Point jobs require a separately prepared/copied bank.
if nargin<1, mode='point'; end
if nargin<2, experiment='waterfall'; end
if nargin<3, task_id=str2double(getenv('SLURM_ARRAY_TASK_ID')); end
root=fileparts(fileparts(mfilename('fullpath')));
old=pwd; oldpath=path;
cleanup=onCleanup(@() restore(old,oldpath)); %#ok<NASGU>
cd(fullfile(root,'matlab','noisy')); addpath(pwd,'-begin');
[configs,banks]=noisy_channel_confirmatory_configs(experiment);
data_root=getenv('ITW_NOISY_ROOT');
if isempty(data_root), data_root=fullfile(root,'results','source','noisy'); end
assert(isfolder(fileparts(data_root)),'Parent of ITW_NOISY_ROOT must exist.');
if strcmp(mode,'bank')
    assert(isfinite(task_id) && mod(task_id,1)==0 && task_id>=0 && task_id<numel(banks));
    cfg=relocate(banks{task_id+1},data_root);
    prepare_bfc_source_bank(cfg,cfg.n_list,noisy_channel_bank_file(cfg,cfg.n_list));
elseif strcmp(mode,'point')
    snrs=numel(configs{1}.ebno_db);
    assert(isfinite(task_id) && mod(task_id,1)==0 && task_id>=0 && task_id<numel(configs)*snrs);
    cfg=relocate(configs{floor(task_id/snrs)+1},data_root);
    ebno=cfg.ebno_db(mod(task_id,snrs)+1);
    file=noisy_channel_result_file(cfg,cfg.n_list,'awgn',ebno);
    if isfile(file)
        saved=load(file,'result'); s=saved.result;
        assert(strcmp(s.config.ldpc.algorithm,cfg.ldpc.algorithm));
        assert(s.config.ldpc.max_iterations==cfg.ldpc.max_iterations);
        assert(s.config.seed==cfg.seed && s.scenario.n==cfg.n_list);
        assert(abs(s.scenario.ebno_db-ebno)<1e-9 && strcmp(s.scenario.channel,'awgn'));
        assert(s.config.bfc.E2==cfg.bfc.E2 && strcmp(s.bank_metadata.func_type,cfg.bfc.func_type));
        assert(s.config.bfc.params.rank==cfg.bfc.params.rank && s.config.bfc.params.beta==cfg.bfc.params.beta);
        assert(s.config.ldpc.rate==cfg.ldpc.rate);
        assert(strcmp(s.bank_metadata.rs_evaluation_order,'extended-zero-first-v1'));
        if s.complete && s.frames==2500 && strcmp(s.stopping.mode,'fixed_frames') && s.version>=5
            fprintf('Validated completed point: %s\n',file); return;
        end
    end
    bankfile=noisy_channel_bank_file(cfg,cfg.n_list);
    assert(isfile(bankfile),'Missing source bank: run a bank job or copy the marked server bank.');
    bank=prepare_bfc_source_bank(cfg,cfg.n_list,bankfile); % compatibility validation
    result=run_noisy_channel_point(cfg,bank,'awgn',ebno,file);
    assert(result.complete && result.frames==2500,'Incomplete fixed-sample job: do not publish this point.');
else
    error('mode must be bank or point');
end
end
function cfg=relocate(cfg,data_root)
old=fullfile('results','noisy_channel_confirmatory_bp');
for field={'results_dir','point_dir','bank_dir'}
    cfg.paths.(field{1})=strrep(cfg.paths.(field{1}),old,data_root);
end
end
function restore(folder,oldpath)
cd(folder); path(oldpath);
end
