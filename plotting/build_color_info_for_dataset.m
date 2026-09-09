function color_info = build_color_info_for_dataset(listexp_data, dataset_id)
%BUILD_COLOR_INFO_FOR_DATASET Color/shape encoding for correlation plots.
%  - llado2026:  discrete coloring by ICTD (ms); marker shape per
%                listener PositionLabel (P0..P3).
%  - simon2010:  continuous coloring by ICTD (ms); marker shape per
%                loudspeaker pair (e.g. 0/45, 45/90, 90/135, 135/180 deg);
%                response SEM error bars from raw trial std.
%  - desena2013: discrete coloring by surround rendering type; marker
%                shape per listener seating position (1 or 2).
%  - ramirez2024: uniform filled markers with response SEM error bars.

color_info = [];
switch dataset_id
    case 'llado2026'
        if ~isfield(listexp_data, 'avgResponse') || ~istable(listexp_data.avgResponse) ...
                || ~ismember('ICTD', listexp_data.avgResponse.Properties.VariableNames)
            return
        end
        color_info = struct( ...
            'kind', 'discrete', ...
            'values', listexp_data.avgResponse.ICTD, ...
            'label', 'ICTD (ms)', ...
            'symmetric', false);
        unique_ictd = unique(listexp_data.avgResponse.ICTD(~isnan(listexp_data.avgResponse.ICTD)));
        color_info.categories = arrayfun(@(v) sprintf('%g ms', v), ...
            unique_ictd(:), 'UniformOutput', false);
        if ismember('PositionLabel', listexp_data.avgResponse.Properties.VariableNames)
            pos_label = string(listexp_data.avgResponse.PositionLabel);
            [unique_pos, ~, pos_idx] = unique(pos_label, 'stable');
            [~, sort_order] = sort(unique_pos);
            inv_order(sort_order) = 1:numel(sort_order); %#ok<AGROW>
            shape_values = inv_order(pos_idx)';
            shape_categories = cellstr(unique_pos(sort_order));
            shape_markers = {'o','s','d','^','v','>','<','p','h'};
            color_info.shape_values = shape_values(:);
            color_info.shape_markers = shape_markers(1:numel(shape_categories));
            color_info.shape_categories = shape_categories;
            color_info.shape_label = 'Listener position';
        end
    case {'simon2010', 'simon2010_separate'}
        if ~isfield(listexp_data, 'avgResponse') || size(listexp_data.avgResponse, 2) < 2
            return
        end
        color_info = struct( ...
            'kind', 'continuous', ...
            'values', listexp_data.avgResponse(:,2), ...
            'label', 'ICTD (ms)', ...
            'symmetric', true);
        if size(listexp_data.avgResponse, 2) >= 4
            lsp_pairs = listexp_data.avgResponse(:, 3:4);
            [unique_pairs, ~, pair_idx] = unique(lsp_pairs, 'rows', 'sorted');
            n_pairs = size(unique_pairs, 1);
            shape_markers = {'o','s','d','^','v','>','<','p','h','x','+'};
            shape_categories = cell(1, n_pairs);
            for ip = 1:n_pairs
                shape_categories{ip} = sprintf('%g/%g°', ...
                    unique_pairs(ip,1), unique_pairs(ip,2));
            end
            color_info.shape_values = pair_idx(:);
            color_info.shape_markers = shape_markers(1:n_pairs);
            color_info.shape_categories = shape_categories;
            color_info.shape_label = 'Loudspeaker pair';
        end
    case 'desena2013'
        n = numel(listexp_data.avgResponseVector);
        n_methods = 4;
        if mod(n, n_methods) ~= 0
            return
        end
        method_vec = repmat((1:n_methods)', n/n_methods, 1);
        rendering_labels = { ...
            'TID', ...
            'HOA', ...
            'HOA in-phase', ...
            'ID'};
        color_info = struct( ...
            'kind', 'discrete', ...
            'values', method_vec, ...
            'label', 'Rendering', ...
            'categories', {rendering_labels});
        n_positions = 2;
        % Seating shapes only when both centre and off-centre halves are
        % present. Position subsets leave the 3D avgResponse unsubset, so
        % numel(avgResponseVector) ~= numel(avgResponse) marks a single seat.
        both_seats_present = true;
        if isfield(listexp_data, 'avgResponse') && isnumeric(listexp_data.avgResponse) ...
                && size(listexp_data.avgResponse, 3) > 1 ...
                && size(listexp_data.avgResponse, 1) == n_positions ...
                && numel(listexp_data.avgResponse) ~= n
            both_seats_present = false;
        end
        if both_seats_present && mod(n, n_positions) == 0
            per_pos = n / n_positions;
            position_vec = repelem((1:n_positions)', per_pos, 1);
            color_info.shape_values = position_vec;
            color_info.shape_markers = {'o', 's'};
            color_info.shape_categories = {'Centre', 'Off-centre'};
            color_info.shape_label = 'Listener position';
        end
    case 'ramirez2024'
        color_info = struct('kind', 'uniform');
    case 'frank2013'
        if ~isfield(listexp_data, 'avgResponse') || ~istable(listexp_data.avgResponse) ...
                || ~ismember('PanAngleDeg', listexp_data.avgResponse.Properties.VariableNames)
            return
        end
        color_info = struct( ...
            'kind', 'continuous', ...
            'values', listexp_data.avgResponse.PanAngleDeg, ...
            'label', 'Pan angle (deg)', ...
            'symmetric', false);
        if ismember('PositionLabel', listexp_data.avgResponse.Properties.VariableNames)
            pos_label = string(listexp_data.avgResponse.PositionLabel);
            [unique_pos, ~, pos_idx] = unique(pos_label, 'stable');
            shape_markers = {'o', 's'};
            [~, shape_categories] = get_listener_positions_for_dataset('frank2013');
            color_info.shape_values = pos_idx(:);
            color_info.shape_markers = shape_markers(1:numel(shape_categories));
            color_info.shape_categories = shape_categories;
            color_info.shape_label = 'Listener position';
        end
end

if ~isempty(color_info)
    color_info = attach_response_sem_xerr(color_info, listexp_data, dataset_id);
end
end

function color_info = attach_response_sem_xerr(color_info, listexp_data, dataset_id)
switch dataset_id
    case 'desena2013'
        if isfield(listexp_data, 'stdResponseVector') ...
                && ~isempty(listexp_data.stdResponseVector)
            n_repetitions = 16;
            if isfield(listexp_data, 'desena2013_NRepetitions')
                n_repetitions = listexp_data.desena2013_NRepetitions;
            end
            color_info.resp_xerr = listexp_data.stdResponseVector(:) ...
                / sqrt(n_repetitions) * 2;
        end
    case 'llado2026'
        if isfield(listexp_data, 'StdLatDeg') && ~isempty(listexp_data.StdLatDeg) ...
                && isfield(listexp_data, 'avgResponse') ...
                && ismember('NTrials', listexp_data.avgResponse.Properties.VariableNames)
            color_info.resp_xerr = listexp_data.StdLatDeg(:) ...
                ./ sqrt(listexp_data.avgResponse.NTrials) * 2;
        end
    case 'ramirez2024'
        if isfield(listexp_data, 'stdResponseVector') && ~isempty(listexp_data.stdResponseVector)
            color_info.resp_xerr = listexp_data.stdResponseVector(:) / sqrt(19) * 2;
        end
    case 'frank2013'
        if isfield(listexp_data, 'stdResponseVector') && ~isempty(listexp_data.stdResponseVector)
            color_info.resp_xerr = listexp_data.stdResponseVector(:) / sqrt(28) * 2;
        end
    case {'simon2010', 'simon2010_separate'}
        if isfield(listexp_data, 'stdResponseVector') ...
                && ~isempty(listexp_data.stdResponseVector) ...
                && isfield(listexp_data, 'nTrials') ...
                && ~isempty(listexp_data.nTrials)
            color_info.resp_xerr = listexp_data.stdResponseVector(:) ...
                ./ sqrt(listexp_data.nTrials(:)) * 2;
        end
end
end
