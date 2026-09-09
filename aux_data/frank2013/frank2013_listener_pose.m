function pose = frank2013_listener_pose(left_offset_m, lsp_radius_m)
%FRANK2013_LISTENER_POSE Listener pose for Frank (2013) VBAP localisation.
%
%   pose = FRANK2013_LISTENER_POSE(left_offset_m, lsp_radius_m) returns the
%   listener position and head yaw for centre or off-centre trials. Off-centre
%   listeners were displaced to the left and faced the front loudspeaker
%   (0 deg), i.e. their head was rotated slightly to the right.
%
%   Azimuth convention: 0 = front, positive = left (codebase).
%
%   Output fields
%       listener_yaw_deg       Head yaw in degrees (negative = right) relative
%                              to the room front axis; 0 at centre.
%       lis_pos_cart           [1 x 2] listener position for
%                              func_binauralise_lsp_signals (room x=front,
%                              y=-lateral).
%       listener_orientation   Head yaw passed to func_binauralise_lsp_signals
%                              so the 0 deg loudspeaker is straight ahead.

arguments
    left_offset_m (1, 1) double {mustBeNonnegative}
    lsp_radius_m (1, 1) double {mustBePositive}
end

% Yaw required to face the front loudspeaker from a leftward offset.
pose.listener_yaw_deg = atan2d(-left_offset_m, lsp_radius_m);

% func_binauralise room frame: x = front, y = -lateral (see generate_frank2013).
pose.lis_pos_cart = [0, -left_offset_m];

if left_offset_m == 0
    pose.listener_orientation = 0;
else
    front_pos_cart = [lsp_radius_m, 0];
    rel_front = front_pos_cart - pose.lis_pos_cart;
    pose.listener_orientation = rad2deg(atan2(rel_front(1), rel_front(2))) - 90;
end
end
