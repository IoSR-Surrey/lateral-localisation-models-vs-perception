function [az_deg, dbg] = re_extended_energy_vector_stitt2016(meta, re_cfg, listexp_data_id)
%RE_EXTENDED_ENERGY_VECTOR_STITT2016 Extended rE azimuth via Stitt et al. (2016).
%
% Wraps the third-party implementation in models/extended_re/stitt2016/
% (Stitt, Bertet & van Walstijn, JAES 2016). Requires that folder on the
% MATLAB path (managed by lateral_angle_models.prj).
%
% Inputs:
%   meta.az_deg, meta.distance_m, meta.gain_lin, meta.delay_s  [1 x L]
%   re_cfg.speed_of_sound_mps, re_cfg.alpha (default 0.1)
%   listexp_data_id : experiment id for ICI convention

az = meta.az_deg(:);
r = meta.distance_m(:);
g = meta.gain_lin(:);
tau = meta.delay_s(:);

if any(r <= 0)
    error('re_extended_energy_vector_stitt2016: non-positive distance encountered.');
end
if ~(numel(az) == numel(r) && numel(r) == numel(g) && numel(g) == numel(tau))
    error('re_extended_energy_vector_stitt2016: metadata vectors must have equal length.');
end

if ~isfield(re_cfg, 'speed_of_sound_mps') || isempty(re_cfg.speed_of_sound_mps)
    speed_mps = 343;
else
    speed_mps = re_cfg.speed_of_sound_mps;
end

if ~isfield(re_cfg, 'alpha') || isempty(re_cfg.alpha)
    alpha = 0.1;
else
    alpha = re_cfg.alpha;
end

listCoords = [0, 0];
arrayCoords = [r .* cosd(az), r .* sind(az)];
G = g(:);

switch listexp_data_id
    case {'desena2013', 'llado2026'}
        % delay_s includes loudspeaker ICTD plus relative delay due to
        % propagation; enervecExt adds propagation, so strip r/c to leave 
        % ICTD / filter-only ICI.
        ICI = tau(:) - r(:) / speed_mps;
    case {'frank2013', 'ramirez2024'}
        % Pure propagation delays in delay_s; enervecExt recomputes them from geometry.
        ICI = zeros(size(tau));
    otherwise
        % ICTD / filter-only delays (propagation handled inside enervecExt).
        ICI = tau(:);
end

rotAz = 0;
if isfield(meta, 'listener_yaw_deg') && ~isempty(meta.listener_yaw_deg)
    rotAz = meta.listener_yaw_deg;
end
E = enervecExt(G, arrayCoords, listCoords, alpha, ICI, rotAz);

den = sum(E.^2);
if den == 0 || any(~isfinite(E))
    az_deg = NaN;
else
    az_deg = atan2d(E(2), E(1));
    if isfield(meta, 'listener_yaw_deg') && ~isempty(meta.listener_yaw_deg)
        az_deg = az_deg - meta.listener_yaw_deg;
    end
end

dbg = struct();
dbg.E = E;
dbg.arrayCoords = arrayCoords;
dbg.listCoords = listCoords;
dbg.G = G;
dbg.ICI = ICI;
dbg.alpha = alpha;
dbg.rotAz = rotAz;

end
