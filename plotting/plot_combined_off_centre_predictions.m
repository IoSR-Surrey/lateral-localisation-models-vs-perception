function plot_combined_off_centre_predictions( ...
    predictions, dataset_ids, model_ids, ...
    compute_r2_ci, compute_slope_ci, fit_ci_opts, ...
    plot_equal_xy_limits, figure_save_opts, simon2010_hemisphere, ...
    listexp_by_dataset, est_yerr)
%PLOT_COMBINED_OFF_CENTRE_PREDICTIONS Pool off-centre trials and plot a grid.
%
% Pools off-centre listening positions from desena2013, llado2026, and
% frank2013 (intersected with dataset_ids), fits metrics on the pooled set,
% and plots one tile per model/parameter combination. Points are coloured
% per dataset using the same palette as the combined plot; llado2026
% off-centre positions P1–P3 are distinguished by marker shape.
%
% Inputs
%   predictions         nDatasets-by-nModels cell of prediction vectors
%   dataset_ids         1-by-nDatasets cell of dataset id strings
%   model_ids           1-by-nModels cell of tile labels (model or combo)
%   listexp_by_dataset  (optional) 1-by-nDatasets cell of listexp structs
%                       matching predictions. Empty cells are reloaded.
%   est_yerr            (optional) nDatasets-by-nModels cell of SEM vectors

if nargin < 9 || isempty(simon2010_hemisphere)
    simon2010_hemisphere = 'fold_lr';
end
if nargin < 8
    figure_save_opts = [];
end
if nargin < 10 || isempty(listexp_by_dataset)
    listexp_by_dataset = {};
end
if nargin < 11
    est_yerr = {};
end

if isempty(model_ids)
    return
end

supported = {'desena2013', 'llado2026', 'frank2013'};
off_ds_ids = {};
off_ds_global = [];
off_masks = {};
off_resp = {};
off_shape_labels = {};
for dsIdx = 1:numel(dataset_ids)
    ds_id = dataset_ids{dsIdx};
    if ~ismember(ds_id, supported)
        continue
    end
    if all(cellfun(@isempty, predictions(dsIdx, :)))
        continue
    end

    listexp_data = local_listexp_for_dataset( ...
        listexp_by_dataset, dsIdx, ds_id);
    trial_mask = get_off_centre_trial_mask(listexp_data, ds_id);

    off_ds_ids{end+1} = ds_id; %#ok<AGROW>
    off_ds_global(end+1) = dsIdx; %#ok<AGROW>
    off_masks{end+1} = trial_mask; %#ok<AGROW>
    off_resp{end+1} = listexp_data.avgResponseVector(:); %#ok<AGROW>
    off_shape_labels{end+1} = local_shape_labels(listexp_data, ds_id, trial_mask); %#ok<AGROW>
end

if isempty(off_ds_ids)
    return
end

errors_to_plot = cell(1, numel(model_ids));
for midx = 1:numel(model_ids)
    model_id = model_ids{midx};
    pooled_pred = [];
    pooled_resp = [];
    pooled_dataset_idx = [];
    pooled_est_yerr = [];
    for offIdx = 1:numel(off_ds_ids)
        dsIdx = off_ds_global(offIdx);
        trial_mask = off_masks{offIdx};
        est_pred = predictions{dsIdx, midx};
        est_resp = off_resp{offIdx};
        if isempty(est_pred)
            error('plot_combined_off_centre_predictions:missing', ...
                'Missing predictions for %s on dataset %s.', ...
                model_id, off_ds_ids{offIdx});
        end
        est_pred = est_pred(:);
        if numel(est_pred) ~= numel(est_resp)
            error('plot_combined_off_centre_predictions:length', ...
                'Length mismatch for %s and dataset %s: pred=%d, resp=%d', ...
                model_id, off_ds_ids{offIdx}, numel(est_pred), numel(est_resp));
        end
        if numel(trial_mask) ~= numel(est_pred)
            error('plot_combined_off_centre_predictions:mask', ...
                'Off-centre mask length (%d) != predictions (%d) for %s.', ...
                numel(trial_mask), numel(est_pred), off_ds_ids{offIdx});
        end

        est_pred = est_pred(trial_mask);
        est_resp = est_resp(trial_mask);
        est_sem = [];
        if ~isempty(est_yerr) && dsIdx <= size(est_yerr, 1) ...
                && midx <= size(est_yerr, 2) && ~isempty(est_yerr{dsIdx, midx})
            est_sem = est_yerr{dsIdx, midx}(:);
            est_sem = est_sem(trial_mask);
        end

        pooled_pred = [pooled_pred; est_pred(:)]; %#ok<AGROW>
        pooled_resp = [pooled_resp; est_resp(:)]; %#ok<AGROW>
        pooled_dataset_idx = [pooled_dataset_idx; ...
            dsIdx * ones(numel(est_pred), 1)]; %#ok<AGROW>
        if ~isempty(est_sem)
            pooled_est_yerr = [pooled_est_yerr; est_sem(:)]; %#ok<AGROW>
        end
    end

    pooled_listexp = struct('avgResponseVector', pooled_resp);
    this_error = struct();
    this_error.error = func_errormetrics(pooled_pred, pooled_listexp);
    this_error.model_id = model_id;
    this_error.dataset_idx = pooled_dataset_idx;
    this_error.position_id = 'off_centre';
    this_error.position_label = 'Off-centre';

    if compute_r2_ci || compute_slope_ci
        pooled_listexp.r2_resample = struct('unit', 'condition');
    end
    if compute_r2_ci
        this_error.r2_ci = bootstrap_r2_ci(pooled_pred, pooled_listexp, fit_ci_opts);
    end
    if compute_slope_ci
        this_error.slope_ci = bootstrap_slope_ci(pooled_pred, pooled_listexp, fit_ci_opts);
        this_error.intercept_ci = bootstrap_intercept_ci(pooled_pred, pooled_listexp, fit_ci_opts);
    end
    if ~isempty(pooled_est_yerr) && numel(pooled_est_yerr) == numel(pooled_pred)
        this_error.est_yerr = pooled_est_yerr;
    end
    errors_to_plot{midx} = this_error;
end

trial_masks_global = cell(1, numel(dataset_ids));
for offIdx = 1:numel(off_ds_ids)
    trial_masks_global{off_ds_global(offIdx)} = off_masks{offIdx};
end

combined_color_info = build_combined_color_info_for_datasets( ...
    dataset_ids, errors_to_plot{1}.dataset_idx, ...
    simon2010_hemisphere, trial_masks_global);
combined_color_info = local_apply_llado_shape_encoding( ...
    combined_color_info, off_shape_labels);
combined_color_info.marker_size = 24;

combined_axis = struct('lim', [-100, 100], ...
    'ticks', [-90, -45, 0, 45, 90]);
plot_estimatederror_grid(errors_to_plot, 'off_centre', combined_color_info, ...
    plot_equal_xy_limits, figure_save_opts, combined_axis, false);
end

function listexp_data = local_listexp_for_dataset(listexp_by_dataset, dsIdx, ds_id)
if dsIdx <= numel(listexp_by_dataset) && ~isempty(listexp_by_dataset{dsIdx})
    listexp_data = listexp_by_dataset{dsIdx};
    return
end
listexp_data = load_listexp_data(ds_id, 0);
listexp_data.listexp_data_id = ds_id;
end

function labels = local_shape_labels(listexp_data, dataset_id, trial_mask)
% Shape-group label per off-centre trial. llado2026 positions map to P1–P3;
% other datasets share a single default shape group.
n_trials = sum(trial_mask);
switch dataset_id
    case 'llado2026'
        labels = string(listexp_data.avgResponse.PositionLabel(trial_mask));
    otherwise
        labels = repmat("other", n_trials, 1);
end
labels = labels(:);
end

function color_info = local_apply_llado_shape_encoding(color_info, shape_labels)
% Encode llado2026 listener positions as marker shapes; keep dataset colour.
pooled_labels = vertcat(shape_labels{:});
if numel(pooled_labels) ~= numel(color_info.values)
    warning('plot_combined_off_centre_predictions:shape_label_length_mismatch', ...
        'Shape labels have %d entries but pooled data has %d. Skipping shape encoding.', ...
        numel(pooled_labels), numel(color_info.values));
    return
end

shape_keys = ["other", "P1", "P2", "P3"];
shape_categories = {'Other datasets', 'P1', 'P2', 'P3'};
shape_markers = {'o', 's', 'd', '^'};
[~, shape_idx] = ismember(pooled_labels, shape_keys);
missing = shape_idx == 0 & pooled_labels ~= "";
if any(missing)
    warning('plot_combined_off_centre_predictions:unknown_shape_label', ...
        'Unknown llado2026 position labels: %s', ...
        strjoin(unique(string(pooled_labels(missing))), ', '));
    shape_idx(missing) = 1;
end

color_info.shape_values = shape_idx(:);
color_info.shape_markers = shape_markers;
color_info.shape_categories = shape_categories;
color_info.shape_label = 'llado2026 position';
end
