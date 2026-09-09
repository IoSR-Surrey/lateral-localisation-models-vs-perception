function az_listener_deg = world_az_to_listener_az(az_world_deg, lis_left_m, ...
    lis_front_m, lsp_radius_m, listener_yaw_deg)
%WORLD_AZ_TO_LISTENER_AZ Convert array-centre azimuth to listener/head frame.
%
%   az_listener_deg = WORLD_AZ_TO_LISTENER_AZ(az_world_deg, lis_left_m, ...
%       lis_front_m, lsp_radius_m)
%   az_listener_deg = WORLD_AZ_TO_LISTENER_AZ(..., listener_yaw_deg)
%
%   Maps a world/array-centre azimuth (piercing point on a loudspeaker ring)
%   to the azimuth of that point as seen from the listener, then subtracts
%   head yaw so 0 deg is the listener's nose. Convention: 0 = front,
%   positive = left. Centre pose (lis_left_m = lis_front_m = yaw = 0) is an
%   identity. NaNs in az_world_deg pass through.

arguments
    az_world_deg double
    lis_left_m (1, 1) double
    lis_front_m (1, 1) double
    lsp_radius_m (1, 1) double {mustBePositive}
    listener_yaw_deg (1, 1) double = 0
end

pt_left = lsp_radius_m * sind(az_world_deg);
pt_front = lsp_radius_m * cosd(az_world_deg);
az_listener_deg = atan2d(pt_left - lis_left_m, pt_front - lis_front_m) ...
    - listener_yaw_deg;
az_listener_deg = mod(az_listener_deg + 180, 360) - 180;
end
