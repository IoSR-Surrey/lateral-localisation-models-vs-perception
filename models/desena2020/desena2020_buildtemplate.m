function [template] = desena2020_buildtemplate(sofa_obj)
%Work in progress
%Based on De Sena et al. 2020
%By Pedro Llado (2025)

obj = sofa_obj;
fs = obj.Data.SamplingRate;
%ids_directions_hor_plane = find(abs(obj.SourcePosition(:,2)) < 5); %Check all azimuths for the horizontal(ish) plane
%ids_directions_hor_plane = find((abs(obj.SourcePosition(:,2)) < 5) & (obj.SourcePosition(:,1) <=90 | obj.SourcePosition(:,1) >=270));
azi_angles = [-90:5:90];
%azi_angles = [-90:90]; % Increasing resolution to 1°, using KU100 from SADIE
ids_directions_hor_plane = SOFAfind(obj,azi_angles,zeros(size(azi_angles)));
azimuth_values = obj.SourcePosition(ids_directions_hor_plane,1);
azimuth_values(azimuth_values>180) = azimuth_values(azimuth_values>180) - 360;

signal_template = [1; zeros(fs/10,1)];
binaural_ir = zeros(length(ids_directions_hor_plane),2,length(obj.Data.IR(1,1,:))+length(signal_template)-1);
for i = 1:length(ids_directions_hor_plane)
    binaural_ir(i,1,:) = conv(squeeze(obj.Data.IR(ids_directions_hor_plane(i),1,:)),signal_template);
    binaural_ir(i,2,:) = conv(squeeze(obj.Data.IR(ids_directions_hor_plane(i),2,:)),signal_template);
end

template = desena2020_estimateinterauralcues(binaural_ir,fs);
template.azimuths = azimuth_values;
template.Hmin = 0;
%% Computing Hmin
% 
% % Compute distance between each direction in the template and each direction in the template

target.cfs = template.cfs;
for itarget = 1:length(template.azimuths)
    target.itd = template.itd(itarget,:);
    target.ild = template.ild(itarget,:);
    target.gtfb_output = template.gtfb_output(itarget);
    distance = desena2020_distance(target,template);
    
    % Weight frequency band by loudness
    distance = desena2020_loudnessweighting(distance,target);
    
    
    % Applying weighting (NOT USED FOR LOCALISATION)
    distance.weightedLikelihood = distance.likelihood_f * distance.weighting_function_SPL';
    distance.Hmin = 0;
    estimated_uncertainty(itarget) = desena2020_estimateuncertainty(distance);
end
distance.Hmin = min(estimated_uncertainty);
template.Hmin = distance.Hmin;

end