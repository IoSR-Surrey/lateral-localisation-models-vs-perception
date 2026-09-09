function est_angle = eval_faller2004(bin_signals, fs, template, fLow, fHigh, spacingERB, hop_size_in_ms, use_parallel)
%EVAL_FALLER2004 Estimate lateral angle per signal with the Faller (2004) model.
%
%   est_angle = EVAL_FALLER2004(bin_signals, fs, template, fLow, fHigh,
%   spacingERB, hop_size_in_ms) runs a gammatone peripheral model followed by
%   neural transduction and the Faller-Merimaa interaural coherence / ITD
%   estimator (prec_fallermerimaa). Per analysis frame, the median of the
%   ITD-based and ILD-based angle estimates is taken.
%
%   The interaural coherence (IC) threshold selects, per frame, only the
%   samples whose IC exceeds the threshold when forming the ITD estimate.
%
%   est_angle = EVAL_FALLER2004(..., use_parallel) sets whether the
%   per-signal loop uses parallel workers (default true; false forces serial).
%
%   Inputs
%       bin_signals    Cell array of [nSamples x 2] binaural signals.
%       fs             Sampling rate in Hz.
%       template       ITD/ILD-to-angle lookup table.
%       fLow, fHigh    Gammatone filterbank frequency range (Hz).
%       spacingERB     Filterbank channel spacing in ERB.
%       hop_size_in_ms Hop between successive frames in ms.
%       use_parallel   Optional logical (default true).
%
%   Output
%       est_angle      [1 x nSignals] mean estimated angle per signal (deg).

if nargin < 8 || isempty(use_parallel)
    use_parallel = true;
end
maxWorkers = Inf;
if ~use_parallel
    maxWorkers = 0;
end

frame_d = 50;          % frame duration in ms
maxlag_d = 48;         % IACC function size in taps
hopsize = fs * 0.001 * hop_size_in_ms;
ic_threshold = 0.95;   % interaural coherence threshold (0 <= theta <= 1)
alpha = 10;            % exponential window time constant in ms

nSignals = numel(bin_signals);
est_angle = nan(1, nSignals);

parfor (isig = 1:nSignals, maxWorkers)
    bin_stim = bin_signals{isig};

    peripheral_out = MC_peripheral_gtfb(bin_stim, fs, fLow, fHigh, spacingERB, ...
        'gtfb_order', 4, 'gtfb_type', "complex", 'gtfb_may2011', "false", ...
        'gtfb_compression_power', 0.23);

    peripheral_out = MC_peripheral_neuraltransduction(peripheral_out, ...
        'lpf_fc', 425, 'lpf_order', 4, 'nt_compression_power', 2, ...
        'apply_envelope', "false");

    monaural_out = MC_monauralProcessing(peripheral_out, 'mon_method', 'none');

    frameCount = ceil((length(bin_stim) - (frame_d / 1000) * fs) / hopsize);
    ccg = prec_fallermerimaa(squeeze(monaural_out.ntout(:, 1, :))', ...
        squeeze(monaural_out.ntout(:, 2, :))', [], [], fs, ic_threshold, ...
        alpha, maxlag_d, frame_d, frameCount, [], [], []);

    % tau axis and ILD do not depend on the frame index, so hoist them.
    % The lag dimension of the transposed crosscorr equals dim 1 of ccg.
    tau = linspace(-1, 1, size(ccg, 1));
    ild = 10 * log10(rms(squeeze(monaural_out.bin_input(:, 2, :)), 1)) ...
        - 10 * log10(rms(squeeze(monaural_out.bin_input(:, 1, :)), 1));
    est_angle_ild = ild2angle(ild, template)';

    est_angle_time = nan(size(ccg, 3), 1);
    for itw = 1:size(ccg, 3)
        crosscorr = ccg(:, :, itw)';        % [Nfreq x lags]
        [~, idx] = max(crosscorr, [], 2);   % [Nfreq x 1]
        itd = (tau(idx) ./ 1000).';         % column vector
        est_angle_itd = itd2angle(itd, template);
        est_angle_time(itw) = median([est_angle_itd; est_angle_ild], 'omitnan');
    end
    est_angle(isig) = mean(est_angle_time);
end
end
