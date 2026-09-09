function [out] = desena2020(test_bin_stim,template,fs)
%Based on De Sena et al. 2020
%By Pedro Llado (2025)

% TODO
% Check NaNs in ILD

%% Compute interaural cues for the binaural stimulus
target = desena2020_estimateinterauralcues(test_bin_stim,fs);

%% Compute distance between the target and each direction in the template
distance = desena2020_distance(target,template);

%% Weight frequency band by loudness
distance = desena2020_loudnessweighting(distance,target);


%% Applying weighting (NOT USED FOR LOCALISATION)
distance.weightedLikelihood = distance.likelihood_f * distance.weighting_function_SPL';

estimated_uncertainty = desena2020_estimateuncertainty(distance);

%% Estimate localisation

estimated_localisation = desena2020_estimatelocalisation(distance,template);

out.estimated_localisation = estimated_localisation;
out.estimated_uncertainty = estimated_uncertainty;
out.target = target;
out.distance = distance;

end