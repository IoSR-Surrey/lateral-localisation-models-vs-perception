function [bin_stim_out] = midEarFilt(bin_stim,fs,midEarFc)
% Input parameters
    % bin_stim: time x 2
    % midEarFc: cut frequencies for a 1st order BPF. If empty, no filter.    

% Output parameters
    % out_stim: time x 2 (filtered)

    if isempty(midEarFc)
        bin_stim_out = bin_stim;
    else
        % from Dietz2011
        [b,a] = butter(1,midEarFc(2)/(fs/2),'low');
        bin_stim = filter(b,a,bin_stim);
        [b,a] = butter(1,midEarFc(1)/(fs/2),'high');
        bin_stim_out = filter(b,a,bin_stim);
    end

