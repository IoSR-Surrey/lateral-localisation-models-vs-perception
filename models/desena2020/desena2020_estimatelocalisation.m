function [estimated_localisation] = desena2020_estimatelocalisation(distance,template)

%plot(distance.weightedLikelihood);

[~,argmax] = max(distance.likelihood_f);
estimated_localisation_f = template.azimuths(argmax);

estimated_localisation = mean(estimated_localisation_f);
end
