function mask = get_listener_position_mask(listexp_data, dataset_id, position_id)
%GET_LISTENER_POSITION_MASK Logical mask over trials for one listener position.
%
%   mask = get_listener_position_mask(listexp_data, dataset_id, position_id)
%
% desena2013: position_id is 'centre'/'off_centre' or 1/2
% llado2026:   position_id is 'P0'..'P3'

    n = numel(listexp_data.avgResponseVector);
    mask = false(n, 1);

    switch dataset_id
        case 'desena2013'
            if mod(n, 2) ~= 0
                error('desena2013: expected even trial count, got %d.', n);
            end
            per_pos = n / 2;
            pos_idx = local_desena_position_index(position_id);
            if pos_idx == 1
                mask(1:per_pos) = true;
            else
                mask(per_pos + 1:end) = true;
            end

        case 'llado2026'
            if ~isfield(listexp_data, 'avgResponse') ...
                    || ~istable(listexp_data.avgResponse) ...
                    || ~ismember('PositionLabel', listexp_data.avgResponse.Properties.VariableNames)
                error('llado2026: avgResponse table with PositionLabel is required.');
            end
            pos_label = string(position_id);
            trial_labels = string(listexp_data.avgResponse.PositionLabel);
            mask = trial_labels == pos_label;

        case 'frank2013'
            if ~isfield(listexp_data, 'avgResponse') ...
                    || ~istable(listexp_data.avgResponse) ...
                    || ~ismember('PositionLabel', listexp_data.avgResponse.Properties.VariableNames)
                error('frank2013: avgResponse table with PositionLabel is required.');
            end
            pos_label = string(position_id);
            if pos_label == "off-centre"
                pos_label = "off_centre";
            end
            trial_labels = string(listexp_data.avgResponse.PositionLabel);
            mask = trial_labels == pos_label;

        otherwise
            error('get_listener_position_mask: unsupported dataset %s', dataset_id);
    end

    if ~any(mask)
        error('get_listener_position_mask: no trials matched position %s in %s.', ...
            string(position_id), dataset_id);
    end
end

function pos_idx = local_desena_position_index(position_id)
    if isnumeric(position_id)
        pos_idx = position_id;
    elseif ischar(position_id) || isstring(position_id)
        switch lower(string(position_id))
            case {"centre", "center", "1"}
                pos_idx = 1;
            case {"off_centre", "off-centre", "offcenter", "2"}
                pos_idx = 2;
            otherwise
                error('desena2013: unknown position_id %s.', string(position_id));
        end
    else
        error('desena2013: position_id must be numeric or text.');
    end

    if pos_idx < 1 || pos_idx > 2
        error('desena2013: position index must be 1 or 2, got %d.', pos_idx);
    end
end
