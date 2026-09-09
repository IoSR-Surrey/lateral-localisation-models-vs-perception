function [V,Y,OAE,CF]=verhulst2012rd(sign,fs,fc,spl,varargin)
%VERHULST2012RD Local copy of verhulst2012pl using isolated temp I/O.

definput.import={'verhulst2012'};  % load defaults from arg_verhulst2012
[flags,keyvals]  = ltfatarghelper([],definput,varargin); %#ok<ASGLU>

if isempty(keyvals.normalize)
    [channels,~]=min(size(sign));
    normalizeRMS=zeros(channels,1);
else
    normalizeRMS=keyvals.normalize;
end

if isempty(keyvals.irr)
    [channels,~]=min(size(sign));
    irregularities=ones(1,channels);
else
    irregularities = keyvals.irr;
end

subject=keyvals.subject;
modfs=96000;
sectionsNo=1000;
[channels,idx]=min(size(sign));
if(idx==2) % transpose it (python C-style row major order)
    sign=sign';
end

stim=zeros(channels,length(resample(sign(1,:),modfs,fs)));
for i=1:channels
    stim(i,:)=resample(sign(i,:),modfs,fs);
    if normalizeRMS(i)
        s_rms=rms(stim(i,:));
        stim(i,:)=stim(i,:)./s_rms;
    end
end

if(ischar(fc) && strcmp(fc,'all')) % probing all sections
    p=sectionsNo;
else
    [p,idx]=max(size(fc));
    if(idx==2)
        fc=fc';
    end
    fc=round(fc);
end

len=length(stim(1,:));

in.stim=stim; in.Fs=modfs; in.channels=channels; in.spl=spl;
in.subject=subject; in.sheraPo=0.061; in.irregularities=irregularities;
in.probes=fc;
out.v=[p len channels];
out.y=[p len channels];
out.E=[len 1 channels];
out.F=[p 1];

this_file = mfilename('fullpath');
[this_dir,~,~] = fileparts(this_file);
module_path = fullfile(this_dir,'run_cochlear_model_rd.py');
output=amt_extern_rd('Python','verhulst2012',module_path,in,out);

Vs=output.v;
Ys=output.y;
OAEs=squeeze(output.E);
CF=output.F;

rl=length(resample(stim(1,:),fs,modfs));
V=zeros(rl,p,channels);
Y=zeros(rl,p,channels);
OAE=zeros(rl,channels);

for i=1:channels
    V(:,:,i)=resample(squeeze(Vs(:,:,i))',fs,modfs);
    Y(:,:,i)=resample(squeeze(Ys(:,:,i))',fs,modfs);
    OAE(:,i)=resample(squeeze(OAEs(:,i)),fs,modfs);
end
