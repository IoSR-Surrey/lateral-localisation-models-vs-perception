function [distance] = desena2020_distance(target,template)
%UNTITLED12 Summary of this function goes here
%   Detailed explanation goes here

distance.Hmin = template.Hmin;

template.itd_normalised = template.itd ./ max(abs(template.itd)); 
template.ild_normalised = template.ild ./ max(abs(template.ild));

target.itd_normalised = target.itd ./ max(abs(template.itd));
target.ild_normalised = target.ild ./ max(abs(template.ild));

%p = 0.5; %norm
p = 0.7; %norm
%p = 1;
%disp("Wrong p-norm!!")

distance.itd = abs(target.itd_normalised - template.itd_normalised).^p;
distance.ild = abs(target.ild_normalised - template.ild_normalised).^p;

% Freq. dependent (as explained by Enzo for Localisation, but not in the paper)
%threshold = 0.6;
threshold = 1;

%f_threshold = 1500;
f_threshold = 15000;

threshold_id = find(template.cfs>f_threshold,1,"first");

%weighting_function_itd_ild = [ interp1([1 threshold_id length(template.cfs)],[0 threshold threshold], 1:length(template.cfs)) ]; % 0 -> only ITD; 1 -> only ILD
%GOOD ONE BELOW!
weighting_function_itd_ild = [ interp1([1 length(template.cfs)],[0 threshold], 1:length(template.cfs)) ]; % 0 -> only ITD; 1 -> only ILD
%weighting_function_itd_ild = ones(1,length(weighting_function_itd_ild))./length(weighting_function_itd_ild)';
%weighting_function_itd_ild = 1./(1 + exp(-[-(length(weighting_function_itd_ild)-1)/2:(length(weighting_function_itd_ild)-1)/2]));
%weighting_function_itd_ild = 1-weighting_function_itd_ild;
%disp("desena2020 doesn't have the right weighting function")

%distance.combined = distance.itd.*(1 - weighting_function_itd_ild) + distance.ild .* weighting_function_itd_ild;
distance.combined = (distance.itd.*(1 - weighting_function_itd_ild) + distance.ild .* weighting_function_itd_ild).^(1/p);


% K = 0.1; it's a normalisation factor, so normalise instead
% distance.likelihood_f = K*-exp(distance.combined); %With the formula, if
% I normalise, it flips the probability distribution and doesn't seem
% right.

%This is correct
%distance.likelihood_f = exp(-distance.combined);
distance.likelihood_f = exp(-distance.combined) ./ sum(exp(-distance.combined));

%distance.likelihood_f = (1-distance.likelihood_f)./sum(1-distance.likelihood_f);
end