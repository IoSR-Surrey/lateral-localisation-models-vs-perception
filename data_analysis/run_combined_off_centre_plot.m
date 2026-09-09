function run_combined_off_centre_plot( ...
    combined_results, combined_dataset_ids, ...
    compute_r2_ci, compute_slope_ci, fit_ci_opts, ...
    skip_plot, plot_equal_xy_limits, figure_save_opts, simon2010_hemisphere)
%RUN_COMBINED_OFF_CENTRE_PLOT Pool off-centre trials across datasets and plot.
%
% Pools off-centre listening positions from desena2013, llado2026, and
% frank2013 (intersected with combined_dataset_ids), fits metrics on the
% pooled set, and saves model_summary_off_centre.pdf. Points are coloured
% per dataset using the same palette as the combined plot; llado2026
% off-centre positions P1–P3 are distinguished by marker shape.

if nargin < 9 || isempty(simon2010_hemisphere)
    simon2010_hemisphere = 'fold_lr';
end
if nargin < 8
    figure_save_opts = [];
end

if skip_plot
    return
end

supported = {'desena2013', 'llado2026', 'frank2013'};
off_results = {};
for dsIdx = 1:numel(combined_dataset_ids)
    if ismember(combined_dataset_ids{dsIdx}, supported)
        off_results{end+1} = combined_results{dsIdx}; %#ok<AGROW>
    end
end

model_ids = local_union_model_ids(off_results);
if isempty(model_ids)
    return
end

n_ds = numel(combined_dataset_ids);
n_models = numel(model_ids);
predictions = cell(n_ds, n_models);
est_yerr = cell(n_ds, n_models);
for dsIdx = 1:n_ds
    if ~ismember(combined_dataset_ids{dsIdx}, supported)
        continue
    end
    S = combined_results{dsIdx};
    for midx = 1:n_models
        predictions{dsIdx, midx} = get_saved_model_predictions(S, model_ids{midx});
        sem = get_saved_model_sem(S, model_ids{midx});
        if ~isempty(sem)
            est_yerr{dsIdx, midx} = sem;
        end
    end
end

plot_combined_off_centre_predictions( ...
    predictions, combined_dataset_ids, model_ids, ...
    compute_r2_ci, compute_slope_ci, fit_ci_opts, ...
    plot_equal_xy_limits, figure_save_opts, simon2010_hemisphere, ...
    {}, est_yerr);
end

function model_ids = local_union_model_ids(saved_results)
model_ids = {};
for ridx = 1:numel(saved_results)
    S = saved_results{ridx};
    if ~isfield(S, 'error_struct_names')
        continue
    end
    for eidx = 1:numel(S.error_struct_names)
        err_struct = S.(S.error_struct_names{eidx});
        if isfield(err_struct, 'model_id')
            model_ids{end+1} = err_struct.model_id; %#ok<AGROW>
        end
    end
end
model_ids = unique(model_ids, 'stable');
model_ids = reorder_model_ids(model_ids, model_plot_order());
end
