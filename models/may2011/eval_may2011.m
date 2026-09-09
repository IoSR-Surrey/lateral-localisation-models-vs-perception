function est_angle = eval_may2011(bin_signals, fs, use_parallel)
%EVAL_MAY2011 Estimate lateral angle per signal with the May (2011) model.
%
%   est_angle = EVAL_MAY2011(bin_signals, fs) runs the May (2011) GMM-based
%   azimuth localisation model (may2011pl) and estimates the azimuth per
%   analysis window with may2011_estazimuthgmm (single source).
%
%   est_angle = EVAL_MAY2011(..., use_parallel) sets whether the per-signal
%   loop uses parallel workers (default true; false forces serial).
%
%   Inputs
%       bin_signals   Cell array of [nSamples x 2] binaural signals.
%       fs            Sampling rate in Hz.
%       use_parallel  Optional logical (default true).
%
%   Output
%       est_angle    [1 x nSignals] mean estimated angle per signal (deg).

if nargin < 3 || isempty(use_parallel)
    use_parallel = true;
end
maxWorkers = Inf;
if ~use_parallel
    maxWorkers = 0;
end

nSources = 1;
nSignals = numel(bin_signals);
est_angle = nan(1, nSignals);

parfor (isig = 1:nSignals, maxWorkers)
    bin_stim = bin_signals{isig};
    out = may2011pl(bin_stim, fs);

    est_angle_time = nan(size(out.loglik, 2), 1);
    for itw = 1:size(out.loglik, 2)
        out_time = struct('rangeAZ', out.rangeAZ, ...
            'loglik', squeeze(out.loglik(:, itw, :)));
        est_angle_time(itw) = -may2011_estazimuthgmm(out_time, 'HIST', nSources, 0);
    end
    est_angle(isig) = mean(est_angle_time);
end
end
