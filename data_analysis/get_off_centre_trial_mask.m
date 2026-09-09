function mask = get_off_centre_trial_mask(listexp_data, dataset_id)
%GET_OFF_CENTRE_TRIAL_MASK Logical mask for off-centre listening positions.
%
%   mask = get_off_centre_trial_mask(listexp_data, dataset_id)
%
% Supported datasets:
%   desena2013  - off_centre seating position
%   frank2013   - off_centre listening position
%   llado2026   - pooled P1, P2, P3 (excludes centre P0)

    switch dataset_id
        case {'desena2013', 'frank2013'}
            mask = get_listener_position_mask(listexp_data, dataset_id, 'off_centre');

        case 'llado2026'
            if ~isfield(listexp_data, 'avgResponse') ...
                    || ~istable(listexp_data.avgResponse) ...
                    || ~ismember('PositionLabel', listexp_data.avgResponse.Properties.VariableNames)
                error('llado2026: avgResponse table with PositionLabel is required.');
            end
            trial_labels = string(listexp_data.avgResponse.PositionLabel);
            mask = trial_labels ~= "P0";
            if ~any(mask)
                error('get_off_centre_trial_mask: no off-centre trials in llado2026.');
            end

        otherwise
            error('get_off_centre_trial_mask: unsupported dataset %s', dataset_id);
    end
end
