function [errormetrics] = func_errormetrics(est_angle,listexp_data)
% Compute error metrics for the prediction
% INPUT
%   est_angle       vector of estimated angles
%   listexp_data    
%       listexp_data.avgResponseVector      struct containing a vector with
%                                           the angles obtained in a listening
%                                           experiment
    
    linear_model = fitlm(listexp_data.avgResponseVector,est_angle);
    errormetrics = linear_model;
end