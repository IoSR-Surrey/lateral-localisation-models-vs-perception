function est_angle = eval_lindemann1986(bin_signals, fs, template, use_parallel)
%EVAL_LINDEMANN1986 Estimate lateral angle per signal with the Lindemann (1986) model.
%
%   est_angle = EVAL_LINDEMANN1986(bin_signals, fs, template) runs the AMT
%   lindemann1986 binaural cross-correlation model on each binaural signal
%   and maps the cross-correlation centroid to an angle via the ITD-to-angle
%   lookup table.
%
%   est_angle = EVAL_LINDEMANN1986(..., use_parallel) sets whether the
%   per-signal loop uses parallel workers (default true; false forces serial).
%
%   Inputs
%       bin_signals   Cell array of [nSamples x 2] binaural signals.
%       fs            Sampling rate in Hz.
%       template      ITD-to-angle lookup table (see itd2angle_lookuptable_pl).
%       use_parallel  Optional logical (default true).
%
%   Output
%       est_angle    [1 x nSignals] mean estimated angle per signal (deg).

if nargin < 4 || isempty(use_parallel)
    use_parallel = true;
end
maxWorkers = Inf;
if ~use_parallel
    maxWorkers = 0;
end

% Lindemann (1986) binaural parameters.
c_s = 0.3;      % stationary inhibition
w_f = 0.035;    % monaural sensitivity
M_f = 6;        % decrease of monaural sensitivity
T_int = 10;     % integration time (ms)
N_1 = 2400;     % sample of the first cross-correlation

nSignals = numel(bin_signals);
est_angle = nan(1, nSignals);

parfor (isig = 1:nSignals, maxWorkers)
    bin_stim = bin_signals{isig};
    cc_tmp = lindemann1986(bin_stim, fs, c_s, w_f, M_f, T_int, N_1);

    est_angle_time = nan(size(cc_tmp, 1), 1);
    for itw = 1:size(cc_tmp, 1)
        cc = squeeze(cc_tmp(itw, :, :));
        itd = zeros(1, size(cc, 2));
        for jj = 1:size(cc, 2)
            itd(jj) = lindemann1986_centroid(cc(:, jj));
        end
        est_angle_time(itw) = median(itd2angle(itd', template), 'omitnan');
    end
    est_angle(isig) = mean(est_angle_time);
end
end
