function [preds_mean, preds_sem, preds_by_hrtf] = aggregate_hrtf_predictions(preds_by_hrtf_cell)
%AGGREGATE_HRTF_PREDICTIONS Mean and SEM of predictions across HRTF runs.
%   [preds_mean, preds_sem, preds_by_hrtf] = AGGREGATE_HRTF_PREDICTIONS(cell)
%   stacks per-HRTF prediction structs, computes per-stimulus mean and SEM
%   for every est_angle_* field, and returns optional nSignals x nHrtfs
%   matrices in preds_by_hrtf.

if isempty(preds_by_hrtf_cell)
    error('aggregate_hrtf_predictions:EmptyInput', ...
        'preds_by_hrtf_cell must contain at least one prediction struct.');
end

n_hrtfs = numel(preds_by_hrtf_cell);
field_names = fieldnames(preds_by_hrtf_cell{1});
est_fields = field_names(startsWith(field_names, 'est_angle_'));

preds_mean = struct();
preds_sem = struct();
preds_by_hrtf = struct();

for fidx = 1:numel(est_fields)
    field_name = est_fields{fidx};
    if strcmp(field_name, 'est_angle_saddler2024_per_model') || ...
        strcmp(field_name, 'est_angle_expected_saddler2024_per_model')
        continue; % Skip to the field if it is 'est_angle_saddler2024_per_model'
    end
    sem_field_name = [field_name '_sem'];

    stack = [];
    for ih = 1:n_hrtfs
        if ~isfield(preds_by_hrtf_cell{ih}, field_name)
            error('aggregate_hrtf_predictions:FieldMismatch', ...
                'Missing field %s in HRTF run %d.', field_name, ih);
        end
        col = preds_by_hrtf_cell{ih}.(field_name)(:);
        stack = [stack, col]; %#ok<AGROW>
    end

    preds_mean.(field_name) = mean(stack, 2, 'omitnan');
    if n_hrtfs > 1
        preds_sem.(sem_field_name) = std(stack, 0, 2, 'omitnan') / sqrt(n_hrtfs);
    else
        preds_sem.(sem_field_name) = zeros(size(stack, 1), 1);
    end
    preds_by_hrtf.(field_name) = stack;
end

time_fields = field_names(startsWith(field_names, 'time_') & endsWith(field_names, '_s'));
for fidx = 1:numel(time_fields)
    field_name = time_fields{fidx};
    times = zeros(n_hrtfs, 1);
    for ih = 1:n_hrtfs
        if ~isfield(preds_by_hrtf_cell{ih}, field_name)
            error('aggregate_hrtf_predictions:FieldMismatch', ...
                'Missing field %s in HRTF run %d.', field_name, ih);
        end
        times(ih) = preds_by_hrtf_cell{ih}.(field_name);
    end
    preds_mean.(field_name) = mean(times, 'omitnan');
end
end
