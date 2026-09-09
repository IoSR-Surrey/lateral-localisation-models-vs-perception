function [peripheral_out] = MC_peripheral_gtfb(bin_stim,fs,fLow,fHigh,spacingERB,varargin)

% Input parameters
    % fLow: lowest characteristic frequency of the filter bank [Hz]
    % fHigh: highest characteristic frequency of the filter bank [Hz]
    % spacingERB: spacing, in terms of ERB, of the center frequencies []

% Output parameter
    % peripheral_out: 
        % .gtfbout = output of the GTFB (nsamples x 2 x nfilters)
        % .cfs

%Future varargin: 
    % Compression: 0.4 Dietz, 0.23 FallerMerimaaDoes compression affect? (Dietz 2011)
    % Order of the GTFB -> 4th order phase compensated? (May 2011)
    % Phase compensation for the GTFB -> phase compensated? (May 2011)

    %% Check input options
    definput.keyvals.gtfb_order = [];
    definput.keyvals.gtfb_type = [];
    definput.keyvals.gtfb_may2011 = [];
    definput.keyvals.gtfb_compression_power = [];
    
    [flags, kv]  = ltfatarghelper({}, ...
                                 definput, varargin);


    if (isempty(kv.gtfb_compression_power))
        kv.gtfb_compression_power = 1;
    end

    %FILTERS CHARACTERISTIC FREQUENCIES
    cfs = erbspacebw(fLow,fHigh,spacingERB);   %hardcoded to get 24 bands %charact. frequencies of the filter bank
    
    if kv.gtfb_may2011 == "true"
        bEar =  0;
        bAlign = 1;
        bInfo = 0;
        [peripheral_out.gtfb(:,1,:),env,GFB] = may2011_gammatone(bin_stim(:,1),fs,fLow,fHigh,length(cfs),bEar,bAlign,bInfo);
        [peripheral_out.gtfb(:,2,:),env,GFB] = may2011_gammatone(bin_stim(:,2),fs,fLow,fHigh,length(cfs),bEar,bAlign,bInfo);

    else
        
        if (isempty(kv.gtfb_order))
            kv.gtfb_order = 4;
        end

        if (isempty(kv.gtfb_type))
            kv.gtfb_type = "complex";
        end
        
        [b,a] = gammatone(cfs,fs,kv.gtfb_order,convertStringsToChars(kv.gtfb_type)); 
        % [b,a] = gammatone(cfs,fs,'complex');        
        peripheral_out.gtfb(:,1,:) = real(ufilterbankz(b,a,squeeze(bin_stim(:,1))));
        peripheral_out.gtfb(:,2,:) = real(ufilterbankz(b,a,squeeze(bin_stim(:,2))));
    
        %apply compression
        peripheral_out.gtfb = peripheral_out.gtfb.*abs(peripheral_out.gtfb).^kv.gtfb_compression_power;
    end
    peripheral_out.cfs = cfs;
    peripheral_out.fs = fs;
end