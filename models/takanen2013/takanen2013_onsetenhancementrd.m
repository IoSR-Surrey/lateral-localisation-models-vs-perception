function [thetaOut, energyOut] = takanen2013_onsetenhancementrd(thetaIn, energyIn, fs, cfs)
%TAKANEN2013_ONSETENHANCEMENTRD Emphasize onsets on direction analysis (rd patch).
%   Copy of AMT takanen2013_onsetenhancement with integer group-delay compensation
%   for odd-length envelope FIR filters (e.g. fs = 44100 Hz).

%% ------ Set parameters for the computations ------------------------------
dims = size(thetaIn);
limit1 = find(cfs > 1000, 1, 'first');
limit2 = find(cfs < 2000, 1, 'last');
originalEnergy = energyIn;
energyIn(:, limit1:limit2) = 0;

rmsOrig = (sqrt((ones(1, size(energyIn, 1)) * (energyIn .^ 2)) ./ size(energyIn, 1)));
x = amt_load('takanen2013', 'periphenergyaverages.mat');
averageEnerg = x.averageEnerg;
scaledEnergy = energyIn ./ (ones(dims(1), 1) * averageEnerg);

win2 = hann(floor(0.003 * fs)) ./ floor(0.003 * fs);
win1 = hann(floor(0.05 * fs)) ./ floor(0.05 * fs);

F = [200 500];
A = [1 0];
dev = [10^(0.1/20) - 1 0.0001];
[M, Wn, beta, typ] = kaiserord(F, A, dev, fs);
b = fir1(M, Wn, typ, kaiser(M + 1, beta), 'noscale');

l = dims(2):-1:1;
g = -1 + 2 ./ exp(-l);
g = 100 * g ./ g(2);
g(g > 100) = 100;
g(g < 1) = 1;

%% ------ 1) Analysis with the two mechanisms --------------------------------

% 1.1) compute the gradient information
envelope = filter(b, 1, scaledEnergy);
% RD: AMT uses envelope = [envelope((length(b)/2):end,:); zeros(length(b)/2-1,dims(2))];
% RD: which fails when length(b) is odd (e.g. fs=44100). Branch on filter parity instead.
filterLen = length(b);
if mod(filterLen, 2) == 0
    groupDelay = filterLen / 2;
    envelope = [envelope(groupDelay:end, :); zeros(groupDelay - 1, dims(2))];
else
    % RD: odd-length FIR — integer group delay (filterLen-1)/2, not length(b)/2
    groupDelay = (filterLen - 1) / 2;
    envelope = [envelope(groupDelay + 1:end, :); zeros(groupDelay, dims(2))];
end
grad = envelope - [zeros(1, dims(2)); envelope(1:end - 1, :)];
clear envelope
grad = grad .* (grad > 0);

x = amt_load('takanen2013', 'onsetmultp.mat');
coeff = x.coeff;
tauOfShortFrame = conv((thetaIn .* (grad .* (ones(dims(1), 1) * g))) * ones(dims(2), 1), win2, 'same' ...
    ) ./ (conv((grad .* (ones(dims(1), 1) * g)) * ones(dims(2), 1), win2, 'same') + 1e-30);
tauOfShortFrame = tauOfShortFrame * ones(1, dims(2));
energOfShortFrame = conv(grad * ones(dims(2), 1), win2, 'same') * ones(1, dims(2));
clear grad

energOfShortFrame = energOfShortFrame .* (ones(dims(1), 1) * coeff);

% 1.2) compute the information over a longer time period
tauOfLongFrame = zeros(dims);
energOfLongFrame = tauOfLongFrame;
for i = 1:dims(2)
    tauOfLongFrame(:, i) = (conv((thetaIn(:, i) .* scaledEnergy(:, i)), win1, 'same') ...
        ) ./ (conv(scaledEnergy(:, i), win1, 'same') + 1e-30);
    energOfLongFrame(:, i) = conv(scaledEnergy(:, i), win1, 'same');
end
clear thetaIn scaledEnergy
%% ------ Combination of the informations obtained ------------------------
envelopeWeight = 5;
thetaOut = (tauOfShortFrame .* energOfShortFrame * envelopeWeight + tauOfLongFrame .* energOfLongFrame) ...
    ./ (energOfLongFrame + energOfShortFrame * envelopeWeight + 1e-30);
clear energOfLongFrame tauOfLongFrame tauOfShortFrame

rms2 = (sqrt((ones(1, size(energOfShortFrame, 1)) * (energOfShortFrame .^ 2)) ./ size(energOfShortFrame, 1)));
energOfShortFrame = energOfShortFrame .* (ones(dims(1), 1) * (2 * rmsOrig ./ (rms2 + 1e-30)));
energyOut = max(originalEnergy, energOfShortFrame);

end
