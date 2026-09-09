function est_angle = eval_takanen2013(bin_signals, fs, window_size, hop_size, Nwindows, listexp_data_id, use_parallel)
%EVAL_TAKANEN2013 Estimate lateral angle per signal with the Takanen (2013) model.
%
%   est_angle = EVAL_TAKANEN2013(bin_signals, fs, window_size, hop_size,
%   Nwindows) runs the Takanen (2013) binaural activity-map model
%   (takanen2013pl). Per analysis window, the angle is the difference between
%   the mean right- and left-pointing activity.
%
%   est_angle = EVAL_TAKANEN2013(..., listexp_data_id, use_parallel) accepts
%   an optional dataset id and whether the per-signal loop uses parallel
%   workers (default true; false forces serial via parfor(..., 0)).
%
%   Inputs
%       bin_signals       Cell array of [nSamples x 2] binaural signals.
%       fs                Sampling rate in Hz.
%       window_size       Analysis window length in samples.
%       hop_size          Hop between successive windows in samples.
%       Nwindows          Number of analysis windows.
%       listexp_data_id   Optional dataset id (default '').
%       use_parallel      Optional logical (default true).
%
%   Output
%       est_angle    [1 x nSignals] mean estimated angle per signal (deg).

if nargin < 6
    listexp_data_id = '';
end
if nargin < 7 || isempty(use_parallel)
    use_parallel = true;
end
% listexp_data_id retained for call-site compatibility.
validateattributes(listexp_data_id, {'char', 'string'}, {});
maxWorkers = Inf;
if ~use_parallel
    maxWorkers = 0;
end

nSignals = numel(bin_signals);
est_angle = nan(1, nSignals);

parfor (isig = 1:nSignals, maxWorkers)
    est_angle(isig) = eval_takanen2013_one( ...
        bin_signals{isig}, fs, window_size, hop_size, Nwindows);
end
end

function est_angle_sig = eval_takanen2013_one(bin_stim, fs, window_size, hop_size, Nwindows)
output = takanen2013pl(bin_stim, fs, 1, 0, 0);

est_angle_time = nan(Nwindows, 1);
for itw = 1:Nwindows
    sample_start = 1 + (itw - 1) * hop_size;
    sample_end = window_size + (itw - 1) * hop_size;
    est_left = mean(real(output.whereLeft(sample_start:sample_end, :)), "all");
    est_right = mean(real(output.whereRight(sample_start:sample_end, :)), "all");
    est_angle_time(itw) = est_right - est_left;
end
est_angle_sig = mean(est_angle_time);
end
