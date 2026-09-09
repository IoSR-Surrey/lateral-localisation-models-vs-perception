function color_info = build_combined_color_info_for_datasets( ...
    dataset_ids, dataset_idx, simon2010_hemisphere, trial_masks)
%BUILD_COMBINED_COLOR_INFO_FOR_DATASETS Color/shape encoding for pooled plots.
%  dataset_ids   cell array of dataset id strings (pool order).
%  dataset_idx   vector of 1..numel(dataset_ids) labels, one per pooled point.
%                Must match the order used when concatenating predictions.
%  simon2010_hemisphere  Optional 'fold_lr' (default) or 'separate' view.
%  trial_masks   Optional cell array of logical masks (one per dataset). When
%                provided, resp_xerr is subset to those trials before pooling.

if nargin < 3 || isempty(simon2010_hemisphere)
    simon2010_hemisphere = 'fold_lr';
end
if nargin < 4
    trial_masks = {};
end

legend_labels = cellfun(@format_dataset_plot_label, dataset_ids, ...
    'UniformOutput', false);
color_info = struct( ...
    'kind', 'discrete', ...
    'label', 'Dataset', ...
    'values', dataset_idx(:), ...
    'categories', {legend_labels});

pooled_resp_xerr = nan(numel(dataset_idx), 1);
for dsIdx = 1:numel(dataset_ids)
    sel = dataset_idx == dsIdx;
    n_pts = sum(sel);
    if n_pts == 0
        continue
    end

    ds_id = dataset_ids{dsIdx};
    if startsWith(ds_id, 'simon2010')
        listexp_data = load_listexp_data('simon2010', 0, ...
            struct('simon2010_hemisphere', simon2010_hemisphere));
        color_ds_id = 'simon2010';
    else
        listexp_data = load_listexp_data(ds_id, 0);
        color_ds_id = ds_id;
    end
    ds_color_info = build_color_info_for_dataset(listexp_data, color_ds_id);
    if isempty(ds_color_info) || ~isfield(ds_color_info, 'resp_xerr') ...
            || isempty(ds_color_info.resp_xerr)
        continue
    end

    resp_xerr = ds_color_info.resp_xerr(:);
    if ~isempty(trial_masks) && dsIdx <= numel(trial_masks) ...
            && ~isempty(trial_masks{dsIdx})
        mask = trial_masks{dsIdx}(:);
        if numel(mask) ~= numel(resp_xerr)
            warning('build_combined_color_info_for_datasets:mask_length_mismatch', ...
                'Dataset %s: trial_mask has %d entries but resp_xerr has %d. Skipping its response error bars.', ...
                dataset_ids{dsIdx}, numel(mask), numel(resp_xerr));
            continue
        end
        resp_xerr = resp_xerr(mask);
    end
    if numel(resp_xerr) ~= n_pts
        warning('build_combined_color_info_for_datasets:resp_xerr_length_mismatch', ...
            'Dataset %s: resp_xerr has %d entries but pooled data has %d. Skipping its response error bars.', ...
            dataset_ids{dsIdx}, numel(resp_xerr), n_pts);
        continue
    end
    pooled_resp_xerr(sel) = resp_xerr;
end

if any(isfinite(pooled_resp_xerr) & pooled_resp_xerr >= 0)
    color_info.resp_xerr = pooled_resp_xerr;
end
end
