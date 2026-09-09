function [interauralcues] = desena2020_estimateinterauralcues(bin_stim,fs)
%Work in progress
%Based on De Sena et al. 2020
%By Pedro Llado (2025)

% Input
% bin_stim [number of signals x 2(l/r) x nsamples]

if ndims(bin_stim) == 3
    Nsignals = size(bin_stim,1);
else
    Nsignals = 1;
    bin_stim_3dim(1,:,:) = bin_stim';
    bin_stim = bin_stim_3dim;
end

for isig = 1:Nsignals
    fLow = 59; %the lowest characteristic frequency of the filter bank
    fHigh = 15100; %the highest
    %fCut = 1000; % cut-off frequency of the low-pass filter
    maxLag= floor(0.001*fs); % IACC-values are computed within-1...1 ms

    %FILTERS CHARACTERISTIC FREQUENCIES
    cfs = erbspacebw(fLow,fHigh,1.6);   %hardcoded to get 24 bands %charact. frequencies of the filter bank

    [b,a] = gammatone(cfs,fs,'complex');
    gtfbout(isig).left = real(ufilterbankz(b,a,squeeze(bin_stim(isig,1,:))));
    gtfbout(isig).right = real(ufilterbankz(b,a,squeeze(bin_stim(isig,2,:))));
    

    % Half wave rectification / Hilbert transform
    f_rectification_Hilbert = 1500;
    channels_neural_transduction = find(cfs<f_rectification_Hilbert,1,'last');

    rectified(isig).left = zeros(size(gtfbout(isig).left));
    rectified(isig).right = zeros(size(gtfbout(isig).right));

    % 1) half-wave rectification below 1.5kHz
    rectified(isig).left(:,1:channels_neural_transduction) = gtfbout(isig).left(:,1:channels_neural_transduction).*(gtfbout(isig).left(:,1:channels_neural_transduction)>0);
    rectified(isig).right(:,1:channels_neural_transduction) = gtfbout(isig).right(:,1:channels_neural_transduction).*(gtfbout(isig).right(:,1:channels_neural_transduction)>0);
    
    % 2) Overwrite using Hilbert transform above 1.5kHz
    rectified(isig).left(:,channels_neural_transduction+1:end) = abs(hilbert(gtfbout(isig).left(:,channels_neural_transduction+1:end)));
    rectified(isig).right(:,channels_neural_transduction+1:end) = abs(hilbert(gtfbout(isig).right(:,channels_neural_transduction+1:end)));
    %rectified(isig).left(:,channels_neural_transduction+1:end) = gtfbout(isig).left(:,channels_neural_transduction+1:end).*(gtfbout(isig).left(:,channels_neural_transduction+1:end)>0);
    %rectified(isig).right(:,channels_neural_transduction+1:end) = gtfbout(isig).right(:,channels_neural_transduction+1:end).*(gtfbout(isig).right(:,channels_neural_transduction+1:end)>0);


    


    % I DON'T THINK THIS IS DONE IN DESENA2020
    % % 2) low-pass filtering of the filter bank output
    % %a first-order IIR filter is used as the low-pass filter
    % beta = exp(-fCut/fs);
    % outSig(isig).left = squeeze(filter(1-beta,[1 -beta],rectified(isig).left));
    % outSig(isig).right = squeeze(filter(1-beta,[1 -beta],rectified(isig).right));

    outSig(isig).left = squeeze(rectified(isig).left);
    outSig(isig).right = squeeze(rectified(isig).right);

    %%%%%COMPUTE INTERAURAL CROSS-CORRELATION AT EACH FREQ BAND
    iaccFuncts = zeros(2*maxLag+1,length(cfs));
    lagValues = (-maxLag:maxLag)./fs;% vector of lags at fs from min to max
    for freqInd=1:length(cfs)
        iaccFuncts(:,freqInd) = xcorr(outSig(isig).left(:,freqInd),...
            outSig(isig).right(:,freqInd),maxLag,'coeff'); %COEFF: 
                                    %Normalizes the sequence so that the
                                    %autocorrelations at zero lag equal 1
    end

    %%%%%COMPUTE ITD FOR EACH FREQ BAND
    [~,lag] = max(iaccFuncts);
    interauralcues.itd(isig,:) = lagValues(lag); % Time corresponding to lag displacement

    %%%%%COMPUTE ILD FOR EACH FREQ BAND
    interauralcues.ild(isig,:) = dbspl(outSig(isig).right(:,:))-dbspl(outSig(isig).left(:,:));
    interauralcues.cfs = cfs;

    %%%%%RETURN GTFB OUTPUT FOR USING IT IN THE LATER STAGES (SPL-DEPENDENT WEIGHTING)
    interauralcues.gtfb_output(isig).left = gtfbout(isig).left;
    interauralcues.gtfb_output(isig).right = gtfbout(isig).right;

    interauralcues.nt_output(isig).left = outSig(isig).left;
    interauralcues.nt_output(isig).right = outSig(isig).right;

    interauralcues.iaccFuncts = iaccFuncts;
end