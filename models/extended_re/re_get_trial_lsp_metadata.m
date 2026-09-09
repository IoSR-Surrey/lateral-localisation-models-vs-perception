function meta = re_get_trial_lsp_metadata(listexp_data_id, listexp_data, trial_idx, re_cfg)
% Return per-trial loudspeaker metadata for the extended rE model.
% Fields:
%   az_deg      [1 x L] loudspeaker azimuths in degrees
%   distance_m  [1 x L] source-listener distances in meters
%   gain_lin    [1 x L] linear loudspeaker gains
%   delay_s     [1 x L] relative delays in seconds
%   notes       text note for diagnostics
%   placeholder_required logical, true when manual setup is needed

meta = struct( ...
    'az_deg', [], ...
    'distance_m', [], ...
    'gain_lin', [], ...
    'delay_s', [], ...
    'notes', "", ...
    'placeholder_required', false);

switch listexp_data_id
    case 'simon2010'
        row = listexp_data.avgResponse(trial_idx,:);
        icld_db = row(1);
        ictd_s = row(2) / 1000;
        az_1 = row(3);
        az_2 = row(4);
        % Simon2010 loudspeaker angles are given in [0..180] with both
        % front and rear hemifield positions. The perceptual responses in
        % this pipeline are lateralised/front-back folded, so mirror rear
        % angles around 90 deg to keep coordinates consistent.
        meta.az_deg = [fold_to_lateral_hemifield(az_1), fold_to_lateral_hemifield(az_2)];
        meta.distance_m = [1, 1];
        meta.gain_lin = [1, db2mag(icld_db)];
        % I still don't know which convention it is here for ICTD, they
        % both seem to return very similar correlations
        meta.delay_s = [ictd_s, 0];
        % if ictd_s > 0
        %     % meta.delay_s = [0, ictd_s];
        % else
        %     meta.delay_s = [-ictd_s, 0];
        % end
        meta.notes = "simon2010 metadata from avgResponse columns";

    case 'desena2013'
        % Signal order in generate_stimuli.m:
        % i_listpos = 1:2, i_lspangle = 1:8, i_renderingmethod = 1:4
        idx0 = trial_idx - 1;
        listpos_idx = floor(idx0 / (8*4)) + 1;
        rem1 = mod(idx0, 8*4);
        target_angle_idx = floor(rem1 / 4) + 1;
        rendering_idx = mod(rem1, 4) + 1;

        if listpos_idx == 1
            listener_angle_deg = 0;
            listener_radius_m = 0;
        elseif listpos_idx == 2
            listener_angle_deg = 135;
            listener_radius_m = 0.3;
        else
            error('desena2013: trial_idx %d out of expected range.', trial_idx);
        end

        % Five-loudspeaker ring setup used in generate_stimuli.m
        lsp_angles_deg = 180:-360/5:-179;
        lsp_radius_m = 2;
        speed_mps = re_cfg.speed_of_sound_mps;

        % Convert to Cartesian (x=front, y=left).
        spk_x = lsp_radius_m * cosd(lsp_angles_deg);
        spk_y = lsp_radius_m * sind(lsp_angles_deg);
        lis_x = listener_radius_m * cosd(listener_angle_deg);
        lis_y = listener_radius_m * sind(listener_angle_deg);

        dx = spk_x - lis_x;
        dy = spk_y - lis_y;

        meta.az_deg = atan2d(dy, dx);
        meta.distance_m = hypot(dx, dy);
        if ~isfield(re_cfg, 'fs') || isempty(re_cfg.fs) || re_cfg.fs <= 0
            error('desena2013: re_cfg.fs must be provided and > 0 for filter delay conversion.');
        end
        if ~isfield(listexp_data, 'desena2013_filter_meta') || isempty(listexp_data.desena2013_filter_meta)
            error('desena2013: desena2013_filter_meta missing in listexp_data. Reload data via load_listexp_data.');
        end

        filt = listexp_data.desena2013_filter_meta(rendering_idx, target_angle_idx);
        meta.gain_lin = filt.gain_lin;
        meta.delay_s = filt.delay_samples / re_cfg.fs + meta.distance_m / speed_mps;
        meta.notes = "desena2013 metadata from ring geometry plus per-LSP filter gain/delay";

    case 'llado2026'
        if ~isfield(listexp_data, 'extended_re_meta') || isempty(listexp_data.extended_re_meta)
            error('llado2026: extended_re_meta missing in listexp_data. Reload data via load_listexp_data.');
        end
        if trial_idx > numel(listexp_data.extended_re_meta)
            error('llado2026: trial_idx %d exceeds precomputed extended_re_meta length.', trial_idx);
        end
        meta = listexp_data.extended_re_meta(trial_idx);
        if ~isfield(meta, 'placeholder_required')
            meta.placeholder_required = false;
        end

    case 'ramirez2024'
        if ~isfield(listexp_data, 'extended_re_meta') || isempty(listexp_data.extended_re_meta)
            error('ramirez2024: extended_re_meta missing in listexp_data. Reload data via load_listexp_data.');
        end
        if trial_idx > numel(listexp_data.extended_re_meta)
            error('ramirez2024: trial_idx %d exceeds precomputed extended_re_meta length.', trial_idx);
        end
        meta = listexp_data.extended_re_meta(trial_idx);
        if ~isfield(meta, 'placeholder_required')
            meta.placeholder_required = false;
        end

    case 'frank2013'
        if ~isfield(listexp_data, 'extended_re_meta') || isempty(listexp_data.extended_re_meta)
            error('frank2013: extended_re_meta missing in listexp_data. Reload data via load_listexp_data.');
        end
        if trial_idx > numel(listexp_data.extended_re_meta)
            error('frank2013: trial_idx %d exceeds precomputed extended_re_meta length.', trial_idx);
        end
        meta = listexp_data.extended_re_meta(trial_idx);
        if ~isfield(meta, 'placeholder_required')
            meta.placeholder_required = false;
        end

    otherwise
        error('Unsupported experiment id: %s', listexp_data_id);
end
end

function az_lat_deg = fold_to_lateral_hemifield(az_deg)
% Map azimuth to front-back folded lateral angle (positive = left).
% 0 -> 0, 45 -> 45, 90 -> 90, 135 -> 45, 180 -> 0,
% -45 -> -45, -135 -> -45, -180 -> 0.
az_sign = 1;
if az_deg < 0
    az_sign = -1;
end
az_abs = abs(az_deg);
az_norm = mod(az_abs, 360);
if az_norm > 180
    az_norm = 360 - az_norm;
end
az_lat_deg = az_sign * min(az_norm, 180 - az_norm);
end
