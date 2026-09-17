function ft_setup()
% Add shared, already validated finite-field and LDPC helpers.
root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(root,'conference_simulation'));
addpath(fullfile(root,'itw2027','matlab','noisy'));
end
