function [Hnorm] = desena2020_estimateuncertainty(distance)

n_angles = length(distance.likelihood_f);
angles = -90:5:90;
alpha = sum(distance.weightedLikelihood.*cos(2.*deg2rad(angles))');
beta = sum(distance.weightedLikelihood.*sin(2.*deg2rad(angles))');

% RD: based on comparison to Enzo's C++ code, we believe this was wrong
% alpha = sum(distance.weightedLikelihood.*cos(2.*[1:n_angles].*2.*pi./n_angles)');
% beta = sum(distance.weightedLikelihood.*sin(2.*[1:n_angles].*2.*pi./n_angles)');

H = 1 - sqrt(alpha.^2 + beta.^2); % circular variance

Hnorm = (H - distance.Hmin) / (1 - distance.Hmin); % High Hnorm indicates high uncertainty
end
