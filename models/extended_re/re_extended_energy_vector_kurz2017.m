function [az_deg, dbg] = re_extended_energy_vector_kurz2017(meta, re_cfg)
%RE_EXTENDED_ENERGY_VECTOR_KURZ2017 Extended rE azimuth (Kurz et al., 2017).
%
%   az_deg = RE_EXTENDED_ENERGY_VECTOR_KURZ2017(meta, re_cfg) computes a
%   horizontal-plane extended energy-vector estimate from loudspeaker metadata.
%
%   rE = sum( (w_r,l * w_tau,l * g_l)^2 * u_l ) / sum( (w_r,l * w_tau,l * g_l)^2 )
%
%   Inputs
%       meta.az_deg, meta.distance_m, meta.gain_lin, meta.delay_s  [1 x L]
%       re_cfg.delay_weight_db_per_s  Delay attenuation (dB/s).
%
%   Output
%       az_deg  Horizontal azimuth estimate in degrees (atan2d(y, x)).

az = meta.az_deg(:).';
if isfield(meta, 'listener_yaw_deg') && ~isempty(meta.listener_yaw_deg)
    az = az - meta.listener_yaw_deg;
end
r = meta.distance_m(:).';
g = meta.gain_lin(:).';
tau = meta.delay_s(:).';

if any(r <= 0)
    error('re_extended_energy_vector_kurz2017: non-positive distance encountered.');
end
if ~(numel(az) == numel(r) && numel(r) == numel(g) && numel(g) == numel(tau))
    error('re_extended_energy_vector_kurz2017: metadata vectors must have equal length.');
end

% Delay weighting should attenuate lagging channels. Shift so earliest is 0.
tau_lag_s = tau - min(tau);

% Distance and delay weights.
w_r = 1 ./ r;
w_tau = 10.^((re_cfg.delay_weight_db_per_s .* tau_lag_s) / 20);

composite = (w_r .* w_tau .* g).^2;

% Horizontal unit vectors.
ux = cosd(az);
uy = sind(az);

num_x = sum(composite .* ux);
num_y = sum(composite .* uy);
den = sum(composite);

if den == 0
    az_deg = NaN;
else
    az_deg = atan2d(num_y, num_x);
end

dbg = struct();
dbg.tau_lag_s = tau_lag_s;
dbg.w_r = w_r;
dbg.w_tau = w_tau;
dbg.composite = composite;
dbg.num = [num_x, num_y];
dbg.den = den;
end
