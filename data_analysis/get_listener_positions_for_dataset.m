function [position_ids, position_labels] = get_listener_positions_for_dataset(dataset_id)
%GET_LISTENER_POSITIONS_FOR_DATASET Return listener positions available in a dataset.
%
%   [position_ids, position_labels] = get_listener_positions_for_dataset(dataset_id)
%
% position_ids    cell array of IDs passed to get_listener_position_mask
% position_labels   cell array of display labels for plots and saved structs

    switch dataset_id
        case 'desena2013'
            position_ids = {'centre', 'off_centre'};
            position_labels = {'Centre', 'Off-centre'};
        case 'llado2026'
            position_ids = {'P0', 'P1', 'P2', 'P3'};
            position_labels = {'P0', 'P1', 'P2', 'P3'};
        case 'frank2013'
            position_ids = {'centre', 'off_centre'};
            position_labels = {'Centre', 'Off-centre'};
        otherwise
            position_ids = {};
            position_labels = {};
    end
end
