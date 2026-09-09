function est_angle = eval_breebaart2001(bin_signals, fs, template, fLow, fHigh, window_size, hop_size, Nwindows, use_parallel)
%EVAL_BREEBAART2001 Estimate lateral angle per signal with the Breebaart (2001) model.
%
%   est_angle = EVAL_BREEBAART2001(bin_signals, fs, template, fLow, fHigh,
%   window_size, hop_size, Nwindows) runs the AMT breebaart2001 peripheral
%   model and estimates the ITD per analysis window from an FFT-based
%   normalised cross-correlation of the left/right peripheral outputs, then
%   maps the per-channel ITD to an angle via the lookup table.
%
%   est_angle = EVAL_BREEBAART2001(..., use_parallel) sets whether the
%   per-signal loop uses parallel workers (default true; false forces serial).
%
%   Inputs
%       bin_signals   Cell array of [nSamples x 2] binaural signals.
%       fs            Sampling rate in Hz.
%       template      ITD-to-angle lookup table.
%       fLow, fHigh   Peripheral filterbank frequency range (Hz).
%       window_size   Analysis window length in samples.
%       hop_size      Hop between successive windows in samples.
%       Nwindows      Number of analysis windows.
%       use_parallel  Optional logical (default true).
%
%   Output
%       est_angle    [1 x nSignals] mean estimated angle per signal (deg).

if nargin < 9 || isempty(use_parallel)
    use_parallel = true;
end
maxWorkers = Inf;
if ~use_parallel
    maxWorkers = 0;
end
periph_args = {'flow', fLow, 'fhigh', fHigh};

maxLag = 0.001; % seconds
maxLagSamples = round(maxLag * fs);
tau = linspace(-1, 1, 2 * maxLagSamples + 1);

nSignals = numel(bin_signals);
est_angle = nan(1, nSignals);

parfor (isig = 1:nSignals, maxWorkers)
    bin_stim = bin_signals{isig};
    [~, ~, outsigl, outsigr] = breebaart2001(bin_stim, fs, 0, 0, periph_args{:});

    est_angle_time = nan(Nwindows, 1);
    for itw = 1:Nwindows
        sample_start = 1 + (itw - 1) * hop_size;
        sample_end = window_size + (itw - 1) * hop_size;
        current_window_L = outsigl(sample_start:sample_end, :);
        current_window_R = outsigr(sample_start:sample_end, :);

        % Batched FFT-based cross-correlation across all frequency channels.
        % Equivalent in spirit to xcorr(L, R, maxLagSamples, 'coeff'), with
        % small numerical drift from FFT rounding.
        Nseg = size(current_window_L, 1);
        nfft = 2^nextpow2(2 * Nseg - 1);
        Lf = fft(current_window_L, nfft);
        Rf = fft(current_window_R, nfft);
        xc_full = real(ifft(Lf .* conj(Rf)));
        xc_shift = fftshift(xc_full, 1);
        center = floor(nfft / 2) + 1;
        crosscorr = xc_shift(center - maxLagSamples:center + maxLagSamples, :);
        denom = sqrt(sum(current_window_L.^2, 1) .* sum(current_window_R.^2, 1));
        crosscorr = crosscorr ./ denom;

        crosscorr = crosscorr.';             % [Nfreq x lags]
        [~, idx] = max(crosscorr, [], 2);    % [Nfreq x 1]
        itd = (tau(idx) ./ 1000).';          % column vector

        est_angle_f = itd2angle(itd, template);
        est_angle_time(itw) = median(est_angle_f, 'omitnan');
    end
    est_angle(isig) = mean(est_angle_time);
end
end
