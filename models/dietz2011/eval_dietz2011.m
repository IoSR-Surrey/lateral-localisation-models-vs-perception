function est_angle = eval_dietz2011(bin_signals, fs, template, window_size, hop_size, Nwindows, use_parallel)
%EVAL_DIETZ2011 Estimate lateral angle per signal with the Dietz (2011) model.
%
%   est_angle = EVAL_DIETZ2011(bin_signals, fs, template, window_size,
%   hop_size, Nwindows) runs the AMT dietz2011 model and, per analysis
%   window, unwraps the fine-structure and envelope ITDs (dietz2011_unwrapitd)
%   before mapping the median ITD to an angle via the lookup table.
%
%   est_angle = EVAL_DIETZ2011(..., use_parallel) sets whether the per-signal
%   loop uses parallel workers (default true; false forces serial).
%
%   Inputs
%       bin_signals   Cell array of [nSamples x 2] binaural signals.
%       fs            Sampling rate in Hz.
%       template      ITD-to-angle lookup table.
%       window_size   Analysis window length in samples.
%       hop_size      Hop between successive windows in samples.
%       Nwindows      Number of analysis windows.
%       use_parallel  Optional logical (default true).
%
%   Output
%       est_angle    [1 x nSignals] mean estimated angle per signal (deg).

if nargin < 7 || isempty(use_parallel)
    use_parallel = true;
end
maxWorkers = Inf;
if ~use_parallel
    maxWorkers = 0;
end

nSignals = numel(bin_signals);
est_angle = nan(1, nSignals);

parfor (isig = 1:nSignals, maxWorkers)
    bin_stim = bin_signals{isig};
    [fine, ~, ild_tmp, env] = dietz2011(bin_stim, fs);

    est_angle_time = nan(Nwindows, 1);
    for itw = 1:Nwindows
        sample_start = 1 + (itw - 1) * hop_size;
        sample_end = window_size + (itw - 1) * hop_size;

        itd_tmp = dietz2011_unwrapitd(fine.itd(sample_start:sample_end, :), ...
            ild_tmp(sample_start:sample_end, 1:12), ...
            fine.f_inst(sample_start:sample_end, :), 2.5);
        env_itd_tmp = dietz2011_unwrapitd(env.itd(sample_start:sample_end, :), ...
            ild_tmp(sample_start:sample_end, 13:23), ...
            env.f_inst(sample_start:sample_end, :), 2.5);

        itd = zeros(1, 23);
        itd(1:12) = median(itd_tmp, 1);
        itd(13:23) = median(env_itd_tmp, 1);

        est_angle_time(itw) = median(itd2angle(itd, template), 'omitnan');
    end
    est_angle(isig) = mean(est_angle_time);
end
end
