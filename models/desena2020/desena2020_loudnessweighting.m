function [distance] = desena2020_loudnessweighting(distance,target)
%UNTITLED12 Summary of this function goes here
%   Detailed explanation goes here
    
    if ~exist('target.gtfb')
        target.gtfb(:,1,:) = target.gtfb_output.left(:,:);
        target.gtfb(:,2,:) = target.gtfb_output.right(:,:);
    end
    %Averaged btw left and right
    signal_rms = (rms(squeeze(target.gtfb(:,1,:))) + rms(squeeze(target.gtfb(:,2,:)))) /2;
    %signal_rms = (rms(squeeze(target.gtfb_output(:,1,:))) + rms(squeeze(target.gtfb_output(:,2,:)))) /2;
    
    phon = 50;
    [spl,f] = iso226(phon);  
    
    if f(end) < target.cfs(end)
        f = [f target.cfs(end)];
        spl = [spl spl(end)];
    end

    spl_cfs = interp1(f,spl,target.cfs);
    
    signal_dB = mag2db(signal_rms);

    id_1kHz = find(target.cfs>1000,1,'first');

    spl_cfs_0 = spl_cfs - spl_cfs(id_1kHz);
    signal_dB_0 = signal_dB - signal_dB(id_1kHz);

    db_diff = signal_dB_0 - spl_cfs_0;
    
    distance.weighting_function_SPL = exp((db_diff)/10);
    distance.weighting_function_SPL = distance.weighting_function_SPL ./ sum(distance.weighting_function_SPL)+eps;
end