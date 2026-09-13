function test_awgn_codeword_symmetry()
% Same LDPC, distinct information words. With sign-aligned AWGN, BP error
% masks agree; with the same physical noise, frame outcomes need not agree.
root=fileparts(fileparts(mfilename('fullpath')));
old=pwd;oldpath=path;cleanup=onCleanup(@()restore(old,oldpath)); %#ok<NASGU>
cd(fullfile(root,'matlab','noisy'));addpath(pwd);
cfg=noisy_channel_confirmatory_configs('threshold_nt40');cfg=cfg{1};
d=derive_bfc_parameters(cfg,40);
assert(d.K==6 && d.m==120 && d.tuples_per_frame==810 && d.padding_bits==0);
H=dvbs2ldpc(.5);ec=ldpcEncoderConfig(H);dc=ldpcDecoderConfig(ec,'bp');
rng(31831,'twister');
a=logical(randi([0 1],ec.NumInformationBits,8));b=logical(randi([0 1],ec.NumInformationBits,8));
xa=1-2*single(ldpcEncode(a,ec));xb=1-2*single(ldpcEncode(b,ec));
for ebno=[0 .8 1.5]
 N0=1/(.5*10^(ebno/10));noise=single(sqrt(N0/2))*randn(size(xa),'single');
 La=single(4/N0)*(xa.*(1+noise));Lb=single(4/N0)*(xb.*(1+noise));
 da=ldpcDecode(La,dc,50,'Multithreaded',false,'OutputFormat','info','DecisionType','hard');
 db=ldpcDecode(Lb,dc,50,'Multithreaded',false,'OutputFormat','info','DecisionType','hard');
 assert(isequal(xor(logical(da),a),xor(logical(db),b)));
 fprintf('PASS: sign-aligned AWGN BP error masks agree at %.1f dB over 8 distinct-codeword pairs.\n',ebno);
end
fprintf('PASS: threshold n_t=40 config: K=6,m=120,S=7140,G=810,padding=0.\n');
end
function restore(folder,oldpath)
cd(folder);path(oldpath);
end
