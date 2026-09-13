function export_evidence(source_root, evidence_root)
% Compact lossless statistical evidence, readable by scipy without HDF5.
root = fileparts(fileparts(mfilename('fullpath')));
src = fullfile(root,'results','source');
dst = fullfile(root,'results','evidence');
if nargin>=1, src=source_root; end
if nargin>=2, dst=evidence_root; end
% dir resolves macOS /tmp to /private/tmp. Canonicalize before taking a
% relative path; substring erasure could otherwise produce "privatenoisy".
old=pwd; cleanup=onCleanup(@()cd(old)); %#ok<NASGU>
cd(src); src=pwd; cd(old);
exported=0;
for kind = {'noiseless','noisy'}
    files = dir(fullfile(src,kind{1},'**','*.mat'));
    for k = 1:numel(files)
        file = fullfile(files(k).folder,files(k).name);
        if contains(file,'source_banks') || contains(file,'checkpoint'), continue; end
        x = load(file);
        if strcmp(kind{1},'noisy')
            if ~isfield(x,'result'), continue; end
            result = x.result;
            assert(result.complete && result.frames == 2500);
            assert(strcmp(result.stopping.mode,'fixed_frames'));
            assert(strcmp(result.config.ldpc.algorithm,'bp'));
            % Target bits are regenerable from the bank seed and not needed
            % for statistical reanalysis. Preserve all counts and frames.
            if isfield(result.bank_metadata.params,'target')
                result.bank_metadata.params = rmfield(result.bank_metadata.params,'target');
            end
            result.evidence_note = 'ID target vector omitted; original seed and source bank retained on server.';
            x = struct('result',result);
        elseif ~isfield(x,'metadata')
            continue;
        end
        assert(startsWith(file,[src filesep]),'Result is outside the source root.');
        rel = file(numel(src)+2:end);
        output = fullfile(dst,rel);
        if ~isfolder(fileparts(output)), mkdir(fileparts(output)); end
        save(output,'-struct','x','-v7');
        exported=exported+1;
    end
end
assert(exported>0,'No compatible evidence files were found.');
fprintf('Exported %d compact evidence files to %s\n',exported,dst);
end
