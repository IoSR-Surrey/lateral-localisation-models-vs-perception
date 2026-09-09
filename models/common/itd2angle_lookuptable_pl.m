function lookup = itd2angle_lookuptable_pl(hrtf,varargin)
%itd2angle_lookuptable Generate an ITD-azimuth lookup table from an HRTF set
%   Usage: lookup = itd2angle_lookuptable(hrtf,fs,model);
%          lookup = itd2angle_lookuptable(hrtf,fs);
%          lookup = itd2angle_lookuptable(hrtf);
%
%   Input parameters:
%       hrtf   : SOFA structure with the HRTF data set.
%       fs     : Optional sampling rate (in Hz). Default: 44100 Hz.
%       model  : Optional string with binaural model to be used to calculate 
%                the perceived azimuth angle:
%
%                - 'dietz2011': DIETZ2011. Default.
%
%                - 'lindemann1986': LINDEMANN1986.
%
%   Output parameters:
%       lookup : Structure containing the results from the polynomial fitting
%                used later by ITD2ANGLE:
%                
%                - p, MU, S*: parameters obtained from the function polyfit 
%                  (polynomial parameters, structure, and statistics), see 
%                  the documentation of polyfit. These parameters describe the
%                  fitting based on the ITDs.
%
%                - p_ild, MU_ild, S_ild*: parameters as above, describing the
%                  fitting based on the ILDs. This output is currently unused in the AMT
%                  and will be removed in the future.
%
%   ITD2ANGLE_LOOKUPTABLE(hrtf) creates a lookup table from the given HRTF data
%   set. This lookup table can be used by the DIETZ2011 or LINDEMANN1986 binaural
%   models to predict the perceived direction of arrival of an auditory event.
%
%   See also: dietz2011 lindemann1986 itd2angle
%
%   References:
%     M. Dietz, S. D. Ewert, and V. Hohmann. Auditory model based direction
%     estimation of concurrent speakers from binaural signals. Speech
%     Communication, 53(5):592--605, 2011.
%     
%     H. Wierstorf, M. Geier, A. Raake, and S. Spors. A free database of
%     head-related impulse response measurements in the horizontal plane with
%     multiple distances. In Proceedings of the 130th Convention of the Audio
%     Engineering Society, 2011.
%     
%     H. Wierstorf, A. Raake, and S. Spors. Binaural assessment of
%     multi-channel reproduction. In J. Blauert, editor, The technology of
%     binaural listening, chapter 10. Springer, Berlin--Heidelberg--New York
%     NY, 2013.
%     
%
%   Url: http://amtoolbox.org/amt-1.6.0/doc/common/itd2angle_lookuptable.php


%   #Author: Hagen Wierstorf (2013): Original implementation.
%   #Author: Robert Baumgartner (2017): SOFA compatibility added.
%   #Author: Piotr Majdak (2024): Major documentation rework.

% This file is licensed unter the GNU General Public License (GPL) either 
% version 3 of the license, or any later version as published by the Free Software 
% Foundation. Details of the GPLv3 can be found in the AMT directory "licences" and 
% at <https://www.gnu.org/licenses/gpl-3.0.html>. 
% You can redistribute this file and/or modify it under the terms of the GPLv3. 
% This file is distributed without any warranty; without even the implied warranty 
% of merchantability or fitness for a particular purpose. 


%% ===== Checking of input parameters ===================================
narginchk(1,4);

definput.flags.model = {'dietz2011','lindemann1986','breebaart2001','breebaart2001dau1997','faller2004'};
definput.keyvals.fs = 44100;
[flags,kv]=ltfatarghelper({'fs'},definput,varargin);

% HRTF format
if isfield(hrtf,'GLOBAL_Conventions')
  flags.do_SOFA = true;
  flags.do_TUB = not(flags.do_SOFA);
  Obj = hrtf;
else
  flags.do_TUB = true;
  flags.do_SOFA = not(flags.do_TUB);
end

%% ===== Configuration ==================================================
% Samplingrate
fs = kv.fs;
% Time of noise used for the calculation (samples)
nsamples = fs;
% Noise type to use
noise_type = 'white';
% SFS Toolbox settings
conf.ir.useinterpolation = true;
conf.ir.useoriglength = true;
conf.fs = fs;
conf.c = 343;
conf.usefracdelay = false;


%% ===== Calculation ====================================================
% Generate noise signal
sig_noise = noise(nsamples,1,noise_type);

% get only the -90 to 90 degree part of the irs set
ele = 0;
idFrontHor = Obj.SourcePosition(:,2) == ele & ... % horizontal plane
    (((Obj.SourcePosition(:,1) >= -90 & Obj.SourcePosition(:,1) < 0) ...
    | Obj.SourcePosition(:,1) >= 270) | ... % front right
    (Obj.SourcePosition(:,1) >= 0 & Obj.SourcePosition(:,1) <= 90)); % front left
azi = Obj.SourcePosition(idFrontHor,1);
azi(azi>180) = azi(azi>180)-360;
% iterate over azimuth angles
nangles = length(azi);
% create an empty mod_itd, because the lindemann model didn't use it
mod_itd = [];

if flags.do_dietz2011

    itd = zeros(nangles,12);
    mod_itd = zeros(nangles,23);
    ild = zeros(nangles,23);

    %PL
    %Compute normalisation factor
    sig_uncorr = SOFAspat(sig_noise,hrtf,0,0);
    sig_uncorr_rms = rms(sig_uncorr);
    lvl_dB = 70;
    sig_corr(:,1) = scaletodbspl(sig_uncorr(:,1),lvl_dB);
    sig_corr(:,2) = scaletodbspl(sig_uncorr(:,2),lvl_dB);
    sig_corr_rms = rms(sig_corr);
    norm_factor = sig_corr_rms./sig_uncorr_rms;
    %PL

    for ii = 1:nangles
        % generate noise coming from the given direction
        sig = SOFAspat(sig_noise,hrtf,azi(ii),ele);

        % PL % Normalising the template at 70 dB SPL
        sig(:,1) = sig(:,1) * norm_factor(1);
        sig(:,2) = sig(:,2) * norm_factor(2);
        %PL

        % calculate binaural parameters
        [fine, cfreqs, ild_tmp, env] = dietz2011(sig,fs);
        % unwrap ITD
        itd_tmp = dietz2011_unwrapitd(fine.itd,ild_tmp(:,1:12),fine.f_inst,2.5);
        env_itd_tmp = dietz2011_unwrapitd(env.itd,ild_tmp(:,13:23),env.f_inst,2.5);
        % calculate the mean about time of the binaural parameters and store
        % them
        itd(ii,1:12) = median(itd_tmp,1);
        itd(ii,13:23) = median(env_itd_tmp,1);
        ild(ii,:) = median(ild_tmp,1);
    end

elseif flags.do_lindemann1986

    itd = zeros(nangles,36);
    ild = zeros(nangles,36);

    %PL
    %Compute normalisation factor
    sig_uncorr = SOFAspat(sig_noise,hrtf,0,0);
    sig_uncorr_rms = rms(sig_uncorr);
    lvl_dB = 70;
    sig_corr(:,1) = scaletodbspl(sig_uncorr(:,1),lvl_dB);
    sig_corr(:,2) = scaletodbspl(sig_uncorr(:,2),lvl_dB);
    sig_corr_rms = rms(sig_corr);
    norm_factor = sig_corr_rms./sig_uncorr_rms;
    %PL

    for ii = 1:nangles
        % generate noise coming from the given direction
        sig = SOFAspat(sig_noise,hrtf,azi(ii),ele);

        % PL % Normalising the template at 70 dB SPL
        sig(:,1) = sig(:,1) * norm_factor(1);
        sig(:,2) = sig(:,2) * norm_factor(2);
        %PL

        % Ten fold upsampling to have a smoother output
        %sig = resample(sig,10*fs,fs);
        % Calculate binaural parameters
        c_s = 0.3; % stationary inhibition
        %w_f = 0; % monaural sensitivity
        w_f = 0.035; % monaural sensitivity
        M_f = 6; % decrease of monaural sensitivity
        T_int = inf; % integration time
        N_1 = 17640; % sample at which first cross-correlation is calculated
        [cc_tmp,dummy,ild(ii,:),cfreqs] = lindemann1986(sig,fs,c_s,w_f,M_f,T_int,N_1);
        clear dummy;
        cc_tmp = squeeze(cc_tmp);
        % Calculate tau (delay line time) axes
        tau = linspace(-1,1,size(cc_tmp,1));
        % find max in cc
        for jj = 1:size(cc_tmp,2)
            % [v,idx] = max(cc_tmp(:,jj));
            % itd(ii,jj) = tau(idx)/1000;
            itd(ii,jj) = lindemann1986_centroid(cc_tmp(:,jj));
        end
    end
elseif flags.do_breebaart2001

%    itd = zeros(nangles,36);
%    ild = zeros(nangles,36);


    %PL
    %Compute normalisation factor
    sig_uncorr = SOFAspat(sig_noise,hrtf,0,0);
    sig_uncorr_rms = rms(sig_uncorr);
    lvl_dB = 70;
    sig_corr(:,1) = scaletodbspl(sig_uncorr(:,1),lvl_dB);
    sig_corr(:,2) = scaletodbspl(sig_uncorr(:,2),lvl_dB);
    sig_corr_rms = rms(sig_corr);
    norm_factor = sig_corr_rms./sig_uncorr_rms;
    %PL
    for ii = 1:nangles
        % generate noise coming from the given direction
        
        sig = SOFAspat(sig_noise,hrtf,azi(ii),ele);
        % PL % Normalising the template at 70 dB SPL
        sig(:,1) = sig(:,1) * norm_factor(1);
        sig(:,2) = sig(:,2) * norm_factor(2);
        %PL
        [~,cfreq,outsigl,outsigr] = breebaart2001(sig,fs,0,0);
        ild(ii,:) = dbspl(outsigr) - dbspl(outsigl);

        maxLag = 0.001;
        iaccFuncts = zeros(round(2*maxLag*fs+1),length(cfreq));
        clear crosscorr
        for freqInd=1:length(cfreq)
            crosscorr(:,freqInd) = xcorr(outsigl(:,freqInd),...
                outsigr(:,freqInd),round(maxLag*fs),'coeff'); %COEFF: 
                                        %Normalizes the sequence so that the
                                        %autocorrelations at zero lag equal 1
        end
        
        crosscorr = crosscorr';
        
        % Calculate tau (delay line time) axes
        tau = linspace(-1,1,size(crosscorr,2));
        % find max in cc
        for jj=1:size(crosscorr,1)
            [~,idx] = max(crosscorr(jj,:));
            itd(ii,jj) = tau(idx)/1000;
        end
    end
elseif flags.do_breebaart2001dau1997

%    itd = zeros(nangles,36);
%    ild = zeros(nangles,36);


    %PL
    %Compute normalisation factor
    sig_uncorr = SOFAspat(sig_noise,hrtf,0,0);
    sig_uncorr_rms = rms(sig_uncorr);
    lvl_dB = 70;
    sig_corr(:,1) = scaletodbspl(sig_uncorr(:,1),lvl_dB);
    sig_corr(:,2) = scaletodbspl(sig_uncorr(:,2),lvl_dB);
    sig_corr_rms = rms(sig_corr);
    norm_factor = sig_corr_rms./sig_uncorr_rms;
    %PL
    for ii = 1:nangles
        % generate noise coming from the given direction
        
        sig = SOFAspat(sig_noise,hrtf,azi(ii),ele);
        % PL % Normalising the template at 70 dB SPL
        sig(:,1) = sig(:,1) * norm_factor(1);
        sig(:,2) = sig(:,2) * norm_factor(2);
        %PL
        [~,cfreq,outsigl,outsigr] = breebaart2001(sig,fs,0,0,'adt_dau1997');
        ild(ii,:) = dbspl(outsigr) - dbspl(outsigl);

        maxLag = 0.001;
        iaccFuncts = zeros(round(2*maxLag*fs+1),length(cfreq));
        clear crosscorr
        for freqInd=1:length(cfreq)
            crosscorr(:,freqInd) = xcorr(outsigl(:,freqInd),...
                outsigr(:,freqInd),round(maxLag*fs),'coeff'); %COEFF: 
                                        %Normalizes the sequence so that the
                                        %autocorrelations at zero lag equal 1
        end
        
        crosscorr = crosscorr';
        
        % Calculate tau (delay line time) axes
        tau = linspace(-1,1,size(crosscorr,2));
        % find max in cc
        for jj=1:size(crosscorr,1)
            [~,idx] = max(crosscorr(jj,:));
            itd(ii,jj) = tau(idx)/1000;
        end
    end

elseif flags.do_faller2004
    % GTFB
    fLow = 80; % in Hz
    fHigh = 8000; % in Hz
    spacingERB = 1; % in ERB
    
    %PL
    %Compute normalisation factor
    sig_uncorr = SOFAspat(sig_noise,hrtf,0,0);
    sig_uncorr_rms = rms(sig_uncorr);
    lvl_dB = 70;
    sig_corr(:,1) = scaletodbspl(sig_uncorr(:,1),lvl_dB);
    sig_corr(:,2) = scaletodbspl(sig_uncorr(:,2),lvl_dB);
    sig_corr_rms = rms(sig_corr);
    norm_factor = sig_corr_rms./sig_uncorr_rms;
    %PL
    
    for ii = 1:nangles
            % generate noise coming from the given direction
            sig = SOFAspat(sig_noise,hrtf,azi(ii),ele);

            % PL % Normalising the template at 70 dB SPL
            sig(:,1) = sig(:,1) * norm_factor(1);
            sig(:,2) = sig(:,2) * norm_factor(2);
            %PL
            peripheral_out = MC_peripheral_gtfb(sig,fs,fLow,fHigh,spacingERB,...
                'gtfb_order',4,'gtfb_type',"complex",'gtfb_may2011',...
                "false",'gtfb_compression_power',0.23);
            
            peripheral_out = MC_peripheral_neuraltransduction(peripheral_out,'lpf_fc',...
                425,'lpf_order',4,'nt_compression_power',2,...
                'apply_envelope',"false");
            
            gaussian = randn(length(sig),2);
            % 9.4dB@2kHz and the rest of bands scaled according to ISO385
            % I don't really understand, so I applied what I think should
            % be very similar
            % [spl,freq] = iso226(11.9); %11.9 is hardcoded to guarantee the 9.4dB@2kHz
            % spl_cfs = interp1(freq,spl,peripheral_out.cfs);
            gaussian = scaletodbspl(gaussian,11.9);
            gaussian_noise = MC_peripheral_gtfb(gaussian,fs,fLow,fHigh,spacingERB,...
                'gtfb_order',4,'gtfb_type',"complex",'gtfb_may2011',...
                "false",'gtfb_compression_power',0.23);
            
            gaussian_noise = MC_peripheral_neuraltransduction(gaussian_noise,'lpf_fc',...
                425,'lpf_order',4,'nt_compression_power',2,...
                'apply_envelope',"false");
            peripheral_out.gaussian_noise = gaussian_noise.ntout;
            
            %monaural_out = MC_monauralProcessing(peripheral_out,'mon_method','gaussianNoise');
            monaural_out = MC_monauralProcessing(peripheral_out,'mon_method','none');
            
            
            maxlag_d = 48;%48; % Size of IACC function in number of taps
            frame_d = size(sig,1)/4; % 
            frameCount = 1;
            
            ic_threshold = 0.95; % IC THRESHOLD ( 0 <= THETA_X <= 1)
            %alpha = 0.01; % EXP WIN TIME CONSTANT ( alpha_f >= 0 )
            alpha = 10; % EXP WIN TIME CONSTANT ( alpha_f >= 0 ) %in ms
            ccg = prec_fallermerimaa(squeeze(monaural_out.ntout(:,1,:))',squeeze(monaural_out.ntout(:,2,:))',[],[],fs,ic_threshold,alpha,maxlag_d,frame_d,frameCount,[],[],[]);  
            
            crosscorr = ccg';
            
            % Calculate tau (delay line time) axes
            tau = linspace(-1,1,size(crosscorr,2));
            % find max in cc
            for jj=1:size(crosscorr,1)
                [~,idx] = max(crosscorr(jj,:));
                itd(ii,jj) = tau(idx)/1000;
            end

            
            %ild(ii,:) = 10*log10(rms(squeeze(monaural_out.bin_input(:,1,:)),1)) - 10*log10(rms(squeeze(monaural_out.bin_input(:,2,:)),1));
            ild(ii,:) = 10*log10(rms(squeeze(monaural_out.bin_input(:,2,:)),1)) - 10*log10(rms(squeeze(monaural_out.bin_input(:,1,:)),1));

    end
end
% Fit the lookup data
for n = 1:size(itd,2)
    [p(:,n),S{n},MU(:,n)] = polyfit(itd(:,n),azi,12);
    [p_ild(:,n),S_ild{n},MU_ild(:,n)] = polyfit(ild(:,n),azi,12);
end
% Create lookup struct
lookup.p = p;
lookup.MU = MU;
lookup.S = S;
lookup.p_ild = p_ild;
lookup.MU_ild = MU_ild;
lookup.S_ild = S_ild;
end


