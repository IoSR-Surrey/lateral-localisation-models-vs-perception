function est_angle = eval_desena2020(bin_signals, fs, template, window_size, hop_size, Nwindows, use_parallel)
%EVAL_DESENA2020 Estimate lateral angle per signal with the De Sena (2020) model.
%
%   est_angle = EVAL_DESENA2020(bin_signals, fs, template, window_size,
%   hop_size, Nwindows) runs the De Sena (2020) template-matching localisation
%   model (desena2020) per analysis window.
%
%   est_angle = EVAL_DESENA2020(..., use_parallel) sets whether the per-signal
%   loop uses parallel workers (default true; false forces serial).
%
%   Inputs
%       bin_signals   Cell array of [nSamples x 2] binaural signals.
%       fs            Sampling rate in Hz.
%       template      De Sena (2020) template (see desena2020_buildtemplate).
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

    est_angle_time = nan(Nwindows, 1);
    for itw = 1:Nwindows
        sample_start = 1 + (itw - 1) * hop_size;
        sample_end = window_size + (itw - 1) * hop_size;
        current_window_L = bin_stim(sample_start:sample_end, 1, :);
        current_window_R = bin_stim(sample_start:sample_end, 2, :);

        out = desena2020([current_window_L current_window_R], template, fs);
        est_angle_time(itw) = out.estimated_localisation;
    end
    est_angle(isig) = mean(est_angle_time);
end
end
