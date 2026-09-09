function bin_signal = func_binauralise_lsp_signals(lsp_signal, lsp_angles, lsp_distances, hrtf_obj,fs,varargin)
% Pedro Llado

% INPUT VARIABLES
    % lsp_signal:           nlsp x nsamples
    % lsp_angles:           in degrees
    % lsp_disances:         in m
    % hrtf_obj:             sofa file
    
    % optional input variables:
    % listener_angle:       in degrees
    % listener_distance:    in m
    % listener_orientation: in degrees
    % lis_pos_cart:    in m (xy coords, instead of angles and distance)

% OUTPUT VARIABLES
    % binaural signal       nsamples * 2(l/r)


%% Check input options
definput.keyvals.listener_angle = [];
definput.keyvals.listener_distance = [];
definput.keyvals.listener_orientation = [];
definput.keyvals.lis_pos_cart = [];


[flags, kv]  = ltfatarghelper({}, ...
                             definput, varargin);

if isempty(kv.listener_angle)
    listener_angle = 0;
else
    listener_angle = kv.listener_angle;
end

if isempty(kv.listener_distance)
    listener_distance = 0;
else
    listener_distance = kv.listener_distance;
end

if isempty(kv.listener_orientation)
    listener_orientation = 0;
else
    listener_orientation = kv.listener_orientation;
end

if length(lsp_distances) == 1
    lsp_distances = lsp_distances*ones(1,length(lsp_angles));
end

if isempty(kv.lis_pos_cart)
    lis_pos_cart = [0 0];
else
    lis_pos_cart = kv.lis_pos_cart;
end

%%
lsp_pos_cart = lsp_distances' .* [cos(deg2rad(-lsp_angles))' sin(deg2rad(-lsp_angles))'];

% NEW
if isempty(kv.lis_pos_cart)
    lis_pos_cart = listener_distance .* [cos(deg2rad(-listener_angle))' sin(deg2rad(-listener_angle))'];
end
% OLD
% %the (-lsp_angles) and  (-listener_angle) is necessary to keep the cos/sin 
% lis_pos_cart = listener_distance .* [cos(deg2rad(-listener_angle))' sin(deg2rad(-listener_angle))'];


lsp_lis_relative_pos_cart = lsp_pos_cart - lis_pos_cart;


lsp_lis_rel_distance = vecnorm(lsp_lis_relative_pos_cart');

% Find the smallest distance in order to delay the signals by the min
% amount
min_rel_distance = min(lsp_lis_rel_distance);

speedofsound = 345;
%ICTD = 1000 * (distance(1,:) - distance(2,:)) ./ speedofsound; % in ms
%ICLD = 10*log10(distance(1,:).^2) - 10*log10(distance(2,:).^2);

for iLsp = 1:length(lsp_angles)
    %Take into account listener orientation
    doa(iLsp,:) = (rad2deg(atan2(lsp_lis_relative_pos_cart(iLsp,1),lsp_lis_relative_pos_cart(iLsp,2))) - 90) - listener_orientation;
    hrtf_ids(iLsp,:) = SOFAfind(hrtf_obj,doa(iLsp,:),zeros(size(doa(iLsp,:)))); % MAYBE NOT! Flipped signed due to angle convention in the HRTF
end

del_0_samples = round(0.030*fs); % 30ms delay as our "zero delay"

hrir_prop = zeros(length(lsp_angles),2, 2*del_0_samples + length(hrtf_obj.Data.IR(1,1,:)) ); 

for iLsp = 1:length(lsp_angles)
    hrir(iLsp,:,:) = hrtf_obj.Data.IR(hrtf_ids(iLsp),:,:);
    
    % Delay only by relative differences between loudspeakers
    del_lsp_samples = round(fs *  (lsp_lis_rel_distance(iLsp)-min_rel_distance) ./ speedofsound);

    % RD: I believe this distance gain calculation is wrong, as it is always 1   
    % gain_lsp_lin = db2mag(10*log10(lsp_lis_rel_distance(iLsp).^2) - 10*log10(lsp_lis_rel_distance(iLsp).^2));
    % it should be 1/lsp_lis_relative_distance
    gain_lsp_lin = 1/lsp_lis_rel_distance(iLsp);
    

    hrir_prop(iLsp,:,del_lsp_samples+1:del_lsp_samples+length(hrir(iLsp,:,:))) = gain_lsp_lin * hrir(iLsp,:,:);

    bin_signal_prop_unmerged(iLsp,1,:) = conv(lsp_signal(iLsp,:)',squeeze(hrir_prop(iLsp,1,:)));
    bin_signal_prop_unmerged(iLsp,2,:) = conv(lsp_signal(iLsp,:)',squeeze(hrir_prop(iLsp,2,:)));
end

bin_signal = squeeze(sum(bin_signal_prop_unmerged,1))';

end