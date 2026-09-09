% BUILD_MODEL_OUTPUT_R2_TABLE
% Build R^2 and regression-slope tables from saved model output files.
%
% With the default configuration this script produces the paper's
%   figures/model_output_r2_comparison.pdf        (R^2 comparison plot)
%   model_output_data/model_output_r2_table.{csv,tex}
%   model_output_data/model_output_runtime_table.tex (average run time table)
% from the cached per-model outputs in model_output_data/ (see README.md).
%
%   Rows:    model IDs.
%   Columns: per listening-experiment dataset and a pooled "combined" column,
%            each reporting R^2 and the OLS slope beta1 (estimated ~ perceived,
%            target = 1) with bootstrap confidence intervals.
%
% Also reports time_per_stim_s: trial-weighted mean seconds per stimulus across
% all per-dataset output files (all HRTFs matching target_sofa_name), as a
% complexity proxy. Combined .mat files are excluded (no timing stored).
%
% The script also runs a paired bootstrap R^2 comparison of every model
% against the best-performing model in each column (with Benjamini-Hochberg
% FDR correction), writes the table to CSV and manuscript-ready LaTeX
% tables (R^2 and runtime-only), and optionally plots the R^2 comparison.
% Optional run_* flags at the top restrict tables/plots to selected models
% (same toggles as compare_models_to_perceptual_data.m); all false => all
% cached models.
%
% Requires per-model .mat files created by compare_models_to_perceptual_data.m:
%   model_output_data/MC_MODEL_OUTPUT_<dataset>_<HRTF>_<model>.mat

clear;
clc;
setup_paths();

%% User options
% Model selection toggles (same flags as compare_models_to_perceptual_data.m).
% If any flag is true, tables/plots include only those models (when cached).
% If all are false, include every model found in the output folder.
run_lindemann1986 = false;
run_breebaart2001 = false;
run_faller2004 = false;
run_may2011 = false;
run_dietz2011 = false;
run_takanen2013 = false;
run_llado2025 = false;
run_extended_re = false;
run_saddler2024 = false;
run_wang2026 = false;
run_vecchiotti2019 = false;

model_output_dir = 'model_output_data';
target_sofa_name = ''; % e.g., 'MULTI_collection'; empty => all cached HRTF labels
save_table_csv = true;
csv_output_filename = 'model_output_r2_table.csv';
save_table_latex = true;
latex_output_filename = 'model_output_r2_table.tex';
latex_runtime_output_filename = 'model_output_runtime_table.tex';
% Same dataset set as combined_dataset_ids in compare_models_to_perceptual_data.m.
% The order here sets the table column order (paper layout) and the pooled
% vector order used by the seeded bootstrap of the Combined column.
combined_dataset_ids = {'llado2026', 'ramirez2024', 'desena2013', 'frank2013', 'simon2010'};
% Must match simon2010_hemisphere in compare_models_to_perceptual_data.m.
% Caches store directed (separate) conditions; this selects the fit/plot view.
simon2010_hemisphere = 'separate';
show_r2_plot = true;
save_r2_plot = true;
figure_output_dir = 'figures';
latex_fig_widths = latex_figure_widths();
r2_plot_filename = 'model_output_r2_comparison.pdf';
r2_plot_max_width_pt = latex_fig_widths.paper_width_pt;
r2_plot_sort_by = 'combined'; % 'combined' only for now

% Paired bootstrap R^2 comparison vs top-performing model (per column).
compute_r2_vs_best = true;
r2_compare_nboot = 10000;
r2_compare_seed = 42;
r2_compare_ci_level = 0.95;

% Bootstrap CIs for per-dataset R^2 and slope (recomputed during assembly).
compute_fit_ci = true;
fit_ci_nboot = 10000;
fit_ci_level = 0.95;
fit_ci_seed = 42;
fit_ci_opts = struct('n_boot', fit_ci_nboot, 'ci_level', fit_ci_level, 'seed', fit_ci_seed);

enabled_model_ids = get_enabled_model_ids_from_flags( ...
    run_lindemann1986, run_breebaart2001, run_faller2004, run_may2011, ...
    run_dietz2011, run_takanen2013, run_llado2025, run_extended_re, ...
    run_saddler2024, run_wang2026, run_vecchiotti2019);

%% Discover datasets and assemble cached outputs
if ~isfolder(model_output_dir)
    error('Model output directory not found: %s', model_output_dir);
end

per_dataset_ids = string(combined_dataset_ids);
selected_entries = struct('dataset', {}, 'sofa_name', {}, 'assembled', {});
for iDataset = 1:numel(per_dataset_ids)
    ds = char(per_dataset_ids(iDataset));
    sofa_names = discover_aggregate_sofa_names(model_output_dir, ds);
    if isempty(sofa_names)
        warning('No model output cache found for dataset: %s', ds);
        continue;
    end
    for iSofa = 1:numel(sofa_names)
        sofa = sofa_names{iSofa};
        if ~isempty(target_sofa_name) && ~strcmp(sofa, target_sofa_name)
            continue;
        end
        multi_dir = '';
        if startsWith(sofa, 'MULTI_')
            cached_hrtfs = discover_hrtf_names_from_cache(model_output_dir, ds);
            for iHrtf = 1:numel(cached_hrtfs)
                cached_models = list_cached_models(model_output_dir, ds, cached_hrtfs{iHrtf});
                if isempty(cached_models)
                    continue;
                end
                piece_path = model_output_cache_path( ...
                    model_output_dir, ds, cached_hrtfs{iHrtf}, cached_models{1});
                piece = load_model_output_piece(piece_path);
                if isfield(piece, 'multi_hrtf_sofa_dir') && ~isempty(piece.multi_hrtf_sofa_dir)
                    multi_dir = piece.multi_hrtf_sofa_dir;
                    break;
                end
            end
        end
        assemble_args = { ...
            'multi_hrtf_sofa_dir', multi_dir, ...
            'compute_r2_ci', compute_fit_ci, ...
            'compute_slope_ci', compute_fit_ci, ...
            'fit_ci_opts', fit_ci_opts, ...
            'simon2010_hemisphere', simon2010_hemisphere};
        if ~isempty(enabled_model_ids)
            assemble_args = [{'model_ids', enabled_model_ids}, assemble_args]; %#ok<AGROW>
        end
        assembled = assemble_model_output(model_output_dir, ds, sofa, assemble_args{:});
        selected_entries(end + 1) = struct( ... %#ok<AGROW>
            'dataset', string(ds), ...
            'sofa_name', string(sofa), ...
            'assembled', assembled);
    end
end

if isempty(selected_entries)
    if isempty(target_sofa_name)
        error('No valid assembled model outputs were found.');
    else
        error('No valid model outputs found for sofa_name: %s', target_sofa_name);
    end
end

%% First pass: collect all model IDs
all_model_ids = strings(0,1);
for iEntry = 1:numel(selected_entries)
    S = selected_entries(iEntry).assembled;
    model_ids = get_model_ids_from_saved_output(S);
    all_model_ids = [all_model_ids; model_ids(:)]; %#ok<AGROW>
end
all_model_ids = unique(all_model_ids);

if ~isempty(enabled_model_ids)
    enabled_model_ids = string(enabled_model_ids(:));
    missing_ids = setdiff(enabled_model_ids, all_model_ids, 'stable');
    if ~isempty(missing_ids)
        warning('Requested model(s) not found in cached outputs: %s', ...
            strjoin(cellstr(missing_ids), ', '));
    end
    all_model_ids = intersect(enabled_model_ids, all_model_ids, 'stable');
end

if isempty(all_model_ids)
    error('No model IDs found in selected output files.');
end

%% Second pass: fill matrix of R^2 values (with bootstrap CI bounds)
dataset_names = string({selected_entries.dataset});
nModels = numel(all_model_ids);
nDatasets = numel(dataset_names);
R2 = nan(nModels, nDatasets);
R2lo = nan(nModels, nDatasets);
R2hi = nan(nModels, nDatasets);
Slope = nan(nModels, nDatasets);
Slopelo = nan(nModels, nDatasets);
Slopehi = nan(nModels, nDatasets);
Pone = nan(nModels, nDatasets);

for j = 1:numel(selected_entries)
    S = selected_entries(j).assembled;
    for i = 1:nModels
        [R2(i,j), R2lo(i,j), R2hi(i,j), Slope(i,j), Slopelo(i,j), Slopehi(i,j), Pone(i,j)] = ...
            get_model_fit_metrics_from_saved_output(S, all_model_ids(i));
    end
end

% Pooled combined metrics from per-dataset assembled outputs.
has_combined_column = numel(combined_dataset_ids) > 1;
combined_r2 = nan(nModels, 1);
combined_r2_lo = nan(nModels, 1);
combined_r2_hi = nan(nModels, 1);
combined_slope = nan(nModels, 1);
combined_slope_lo = nan(nModels, 1);
combined_slope_hi = nan(nModels, 1);
combined_p_one = nan(nModels, 1);
if has_combined_column
    for i = 1:nModels
        [combined_r2(i), combined_r2_lo(i), combined_r2_hi(i), ...
            combined_slope(i), combined_slope_lo(i), combined_slope_hi(i), ...
            combined_p_one(i)] = compute_pooled_fit_metrics( ...
            selected_entries, combined_dataset_ids, all_model_ids(i), fit_ci_opts, ...
            simon2010_hemisphere);
    end
else
    warning('Only one dataset available; combined_r2 will be NaN.');
end

plot_dataset_labels = [ ...
    arrayfun(@(s) string(format_dataset_plot_label(s)), dataset_names(:)); ...
    "Combined"];
R2_plot = [R2, combined_r2];
R2lo_plot = [R2lo, combined_r2_lo];
R2hi_plot = [R2hi, combined_r2_hi];

%% Third pass: trial-weighted average runtime per stimulus (complexity proxy)
runtime_entries = selected_entries;
time_per_stim_s = nan(nModels, 1);
for i = 1:nModels
    model_id = all_model_ids(i);
    total_time = 0;
    total_stim = 0;
    for iEntry = 1:numel(runtime_entries)
        S = runtime_entries(iEntry).assembled;
        t = get_saved_model_runtime_s(S, model_id);
        if ~isfinite(t)
            continue;
        end
        try
            n_stim = numel(get_saved_model_predictions(S, model_id));
        catch
            continue;
        end
        if n_stim < 1
            continue;
        end
        total_time = total_time + t;
        total_stim = total_stim + n_stim;
    end
    if total_stim > 0
        time_per_stim_s(i) = total_time / total_stim;
    end
end

%% Paired R^2 comparison vs best model (per dataset and combined)
nCompareCols = nDatasets + has_combined_column;
DeltaR2 = nan(nModels, nCompareCols);
DeltaR2lo = nan(nModels, nCompareCols);
DeltaR2hi = nan(nModels, nCompareCols);
PvsBest = nan(nModels, nCompareCols);
PvsBestFdr = nan(nModels, nCompareCols);
SigVsBest = false(nModels, nCompareCols);
RefModelCol = strings(nModels, nCompareCols);

if compute_r2_vs_best
    compare_opts = struct('n_boot', r2_compare_nboot, ...
        'ci_level', r2_compare_ci_level, 'seed', r2_compare_seed);

    for j = 1:nDatasets
        S = selected_entries(j).assembled;
        listexp_data = load_listexp_matching_assembled(S, simon2010_hemisphere);
        if ~isstruct(listexp_data)
            warning('No perceptual data for dataset %s (listexp_data_id=%s); skipping vs-best.', ...
                dataset_names(j), char(S.listexp_data_id));
            continue;
        end
        [ref_idx, ref_id] = pick_reference_model_index(R2(:, j), all_model_ids, S);
        if isempty(ref_idx)
            warning('No comparable reference model for dataset %s; skipping vs-best.', ...
                dataset_names(j));
            continue;
        end
        fprintf('Reference model for %s: %s (R^2=%.4f)\n', ...
            dataset_names(j), ref_id, R2(ref_idx, j));
        RefModelCol(:, j) = repmat(ref_id, nModels, 1);
        est_ref = get_saved_model_predictions(S, ref_id);
        DeltaR2(ref_idx, j) = 0;
        PvsBest(ref_idx, j) = NaN;

        for i = 1:nModels
            if i == ref_idx
                continue;
            end
            try
                est_ch = get_saved_model_predictions(S, all_model_ids(i));
                cmp = bootstrap_compare_r2_ci(est_ref, est_ch, listexp_data, compare_opts);
                DeltaR2(i, j) = cmp.delta_r2;
                DeltaR2lo(i, j) = cmp.delta_r2_ci(1);
                DeltaR2hi(i, j) = cmp.delta_r2_ci(2);
                PvsBest(i, j) = cmp.p_two;
            catch ME
                warning('vs-best comparison failed for %s vs %s (%s): %s', ...
                    ref_id, all_model_ids(i), dataset_names(j), ME.message);
            end
        end
        PvsBestFdr(:, j) = apply_fdr_bh_column(PvsBest(:, j), ref_idx);
        SigVsBest(:, j) = PvsBestFdr(:, j) < 0.05;
        SigVsBest(ref_idx, j) = false;
    end

    if has_combined_column
        j = nCompareCols;
        pooled_resp = [];
        pooled_preds = cell(nModels, 1);
        for dsIdx = 1:numel(combined_dataset_ids)
            ds_id = string(combined_dataset_ids{dsIdx});
            entry_idx = find(dataset_names == ds_id, 1);
            if isempty(entry_idx)
                warning('No saved output for combined component %s; skipping in pooled vs-best.', ...
                    combined_dataset_ids{dsIdx});
                continue;
            end
            Sds = selected_entries(entry_idx).assembled;
            ld = load_listexp_matching_assembled(Sds, simon2010_hemisphere);
            if ~isstruct(ld)
                warning('No perceptual data for %s; skipping in pooled vs-best.', ...
                    char(Sds.listexp_data_id));
                continue;
            end
            pooled_resp = [pooled_resp; ld.avgResponseVector(:)]; %#ok<AGROW>
            for i = 1:nModels
                if isempty(pooled_preds{i})
                    pooled_preds{i} = [];
                end
                if has_saved_model_predictions(Sds, all_model_ids(i))
                    pooled_preds{i} = [pooled_preds{i}; ...
                        get_saved_model_predictions(Sds, all_model_ids(i))]; %#ok<AGROW>
                end
            end
        end
        if isempty(pooled_resp)
            warning('No pooled perceptual responses for combined vs-best; skipping.');
        else
        pooled_listexp = struct( ...
            'avgResponseVector', pooled_resp, ...
            'r2_resample', struct('unit', 'condition'));
        % Reference from combined R^2; predictions stacked from per-dataset files
        % (combined .mat stores error structs only, not est_angle_*).
        [ref_idx, ref_id] = pick_reference_model_index(combined_r2, all_model_ids, ...
            build_pooled_prediction_availability_mask(pooled_preds, numel(pooled_resp)));
        if ~isempty(ref_idx)
            fprintf('Reference model for combined: %s (R^2=%.4f)\n', ...
                ref_id, combined_r2(ref_idx));
            RefModelCol(:, j) = repmat(ref_id, nModels, 1);
            est_ref = pooled_preds{ref_idx};
            if numel(est_ref) ~= numel(pooled_resp)
                warning('Combined reference %s prediction length mismatch; skipping.', ref_id);
            else
                DeltaR2(ref_idx, j) = 0;
                PvsBest(ref_idx, j) = NaN;
                for i = 1:nModels
                    if i == ref_idx
                        continue;
                    end
                    est_ch = pooled_preds{i};
                    if isempty(est_ch) || numel(est_ch) ~= numel(pooled_resp)
                        continue;
                    end
                    try
                        cmp = bootstrap_compare_r2_ci(est_ref, est_ch, pooled_listexp, compare_opts);
                        DeltaR2(i, j) = cmp.delta_r2;
                        DeltaR2lo(i, j) = cmp.delta_r2_ci(1);
                        DeltaR2hi(i, j) = cmp.delta_r2_ci(2);
                        PvsBest(i, j) = cmp.p_two;
                    catch ME
                        warning('vs-best comparison failed for %s vs %s (combined): %s', ...
                            ref_id, all_model_ids(i), ME.message);
                    end
                end
                PvsBestFdr(:, j) = apply_fdr_bh_column(PvsBest(:, j), ref_idx);
                SigVsBest(:, j) = PvsBestFdr(:, j) < 0.05;
                SigVsBest(ref_idx, j) = false;
            end
        else
            warning('No combined reference model with pooled predictions; skipping combined vs-best.');
        end
        end
    end
end

% Assemble interleaved columns: <dataset>, <dataset>_lo, <dataset>_hi, then slope group.
table_data = [];
column_names = {};
for j = 1:nDatasets
    table_data = [table_data, R2(:,j), R2lo(:,j), R2hi(:,j)]; %#ok<AGROW>
    ds = char(dataset_names(j));
    column_names = [column_names, {ds, [ds '_lo'], [ds '_hi']}]; %#ok<AGROW>
end
table_data = [table_data, combined_r2, combined_r2_lo, combined_r2_hi];
column_names = [column_names, {'combined_r2', 'combined_r2_lo', 'combined_r2_hi'}];

for j = 1:nDatasets
    table_data = [table_data, Slope(:,j), Slopelo(:,j), Slopehi(:,j), Pone(:,j)]; %#ok<AGROW>
    ds = char(dataset_names(j));
    column_names = [column_names, ...
        {[ds '_slope'], [ds '_slope_lo'], [ds '_slope_hi'], [ds '_p_one']}]; %#ok<AGROW>
end
table_data = [table_data, combined_slope, combined_slope_lo, combined_slope_hi, combined_p_one];
column_names = [column_names, ...
    {'combined_slope', 'combined_slope_lo', 'combined_slope_hi', 'combined_p_one'}];

vs_best_ref_cols = {};
vs_best_ref_data = {};
if compute_r2_vs_best && nCompareCols > 0
    for j = 1:nDatasets
        ds = char(dataset_names(j));
        table_data = [table_data, ...
            double(SigVsBest(:, j)), DeltaR2(:, j), DeltaR2lo(:, j), DeltaR2hi(:, j), ...
            PvsBest(:, j), PvsBestFdr(:, j)]; %#ok<AGROW>
        column_names = [column_names, ...
            {[ds '_sig_vs_best'], [ds '_delta_r2_vs_best'], ...
            [ds '_delta_r2_lo'], [ds '_delta_r2_hi'], [ds '_p_vs_best'], ...
            [ds '_p_vs_best_fdr']}]; %#ok<AGROW>
        vs_best_ref_cols{end+1} = [ds '_ref_model']; %#ok<AGROW>
        vs_best_ref_data{end+1} = RefModelCol(:, j); %#ok<AGROW>
    end
    if has_combined_column
        table_data = [table_data, ...
            double(SigVsBest(:, end)), DeltaR2(:, end), DeltaR2lo(:, end), DeltaR2hi(:, end), ...
            PvsBest(:, end), PvsBestFdr(:, end)]; %#ok<AGROW>
        column_names = [column_names, ...
            {'combined_sig_vs_best', 'combined_delta_r2_vs_best', ...
            'combined_delta_r2_lo', 'combined_delta_r2_hi', ...
            'combined_p_vs_best', 'combined_p_vs_best_fdr'}]; %#ok<AGROW>
        vs_best_ref_cols{end+1} = 'combined_ref_model'; %#ok<AGROW>
        vs_best_ref_data{end+1} = RefModelCol(:, end); %#ok<AGROW>
    end
end

table_data = [table_data, time_per_stim_s];
column_names = [column_names, {'time_per_stim_s'}];

Fit_table = array2table(table_data, ...
    'RowNames', cellstr(all_model_ids), ...
    'VariableNames', matlab.lang.makeValidName(column_names));

for k = 1:numel(vs_best_ref_cols)
    col_name = matlab.lang.makeValidName(vs_best_ref_cols{k});
    Fit_table.(col_name) = vs_best_ref_data{k};
end

disp('Model fit table (R^2, slope CIs, vs-best comparisons, and time_per_stim_s):');
disp(Fit_table);

if save_table_csv
    out_csv = fullfile(model_output_dir, csv_output_filename);
    writetable(Fit_table, out_csv, 'WriteRowNames', true);
    fprintf('Saved model fit table CSV (R^2 + slope + runtime) to: %s\n', out_csv);
end

if save_table_latex
    out_tex = fullfile(model_output_dir, latex_output_filename);
    write_model_r2_latex_table(out_tex, all_model_ids, dataset_names, ...
        R2, combined_r2, SigVsBest, RefModelCol, time_per_stim_s);
    fprintf('Saved model fit LaTeX table to: %s\n', out_tex);

    out_runtime_tex = fullfile(model_output_dir, latex_runtime_output_filename);
    write_model_runtime_latex_table(out_runtime_tex, all_model_ids, time_per_stim_s);
    fprintf('Saved model runtime LaTeX table to: %s\n', out_runtime_tex);
end

if show_r2_plot
    sofa_names = unique(string({selected_entries.sofa_name}));
    plot_title_suffix = '';
    if isscalar(sofa_names)
        plot_title_suffix = char(sofa_names);
    end
    fig = plot_model_r2_comparison(all_model_ids, plot_dataset_labels, ...
        R2_plot, R2lo_plot, R2hi_plot, r2_plot_sort_by, plot_title_suffix, ...
        r2_plot_max_width_pt);
    if save_r2_plot
        out_fig = fullfile(figure_output_dir, r2_plot_filename);
        save_figure_for_latex(fig, out_fig, r2_plot_max_width_pt);
        fprintf('Saved R^2 comparison figure PDF to: %s\n', out_fig);
    end
end

%% Local helpers
function enabled_model_ids = get_enabled_model_ids_from_flags( ...
    run_lindemann1986, run_breebaart2001, run_faller2004, run_may2011, ...
    run_dietz2011, run_takanen2013, run_llado2025, run_extended_re, ...
    run_saddler2024, run_wang2026, run_vecchiotti2019)
%GET_ENABLED_MODEL_IDS_FROM_FLAGS Map run_* toggles to model id cell array.
flag_specs = { ...
    run_lindemann1986, 'lindemann1986'; ...
    run_breebaart2001, 'breebaart2001'; ...
    run_faller2004, 'faller2004'; ...
    run_may2011, 'may2011'; ...
    run_dietz2011, 'dietz2011'; ...
    run_takanen2013, 'takanen2013'; ...
    run_llado2025, 'llado2025'; ...
    run_extended_re, 'kurz2017'; ...
    run_extended_re, 'stitt2016'; ...
    run_extended_re, 'rE'; ...
    run_saddler2024, 'saddler2024'; ...
    run_wang2026, 'wang2026'; ...
    run_vecchiotti2019, 'vecchiotti2019'};
enabled_model_ids = {};
for iSpec = 1:size(flag_specs, 1)
    if flag_specs{iSpec, 1}
        enabled_model_ids{end + 1} = flag_specs{iSpec, 2}; %#ok<AGROW>
    end
end
enabled_model_ids = unique(enabled_model_ids, 'stable');
end

function [r2, r2_lo, r2_hi, slope, slope_lo, slope_hi, p_one] = ...
        compute_pooled_fit_metrics(selected_entries, combined_dataset_ids, model_id, ...
        fit_ci_opts, simon2010_hemisphere)
%COMPUTE_POOLED_FIT_METRICS Fit metrics for a model pooled across datasets.
if nargin < 5 || isempty(simon2010_hemisphere)
    simon2010_hemisphere = 'fold_lr';
end
r2 = NaN;
r2_lo = NaN;
r2_hi = NaN;
slope = NaN;
slope_lo = NaN;
slope_hi = NaN;
p_one = NaN;

pooled_pred = [];
pooled_resp = [];
dataset_names = string({selected_entries.dataset});
for dsIdx = 1:numel(combined_dataset_ids)
    ds_id = string(combined_dataset_ids{dsIdx});
    entry_idx = find(dataset_names == ds_id, 1);
    if isempty(entry_idx)
        return;
    end
    S = selected_entries(entry_idx).assembled;
    if ~has_saved_model_predictions(S, model_id)
        return;
    end
    listexp_data = load_listexp_matching_assembled(S, simon2010_hemisphere);
    est_pred = get_saved_model_predictions(S, model_id);
    pooled_pred = [pooled_pred; est_pred(:)]; %#ok<AGROW>
    pooled_resp = [pooled_resp; listexp_data.avgResponseVector(:)]; %#ok<AGROW>
end

pooled_listexp = struct( ...
    'avgResponseVector', pooled_resp, ...
    'r2_resample', struct('unit', 'condition'));
lm = func_errormetrics(pooled_pred, pooled_listexp);
try
    r2 = lm.Rsquared.Ordinary;
catch
end
try
    slope = lm.Coefficients.Estimate(2);
catch
end

r2_ci = bootstrap_r2_ci(pooled_pred, pooled_listexp, fit_ci_opts);
if isstruct(r2_ci) && isfield(r2_ci, 'r2_ci') && numel(r2_ci.r2_ci) == 2
    r2_lo = r2_ci.r2_ci(1);
    r2_hi = r2_ci.r2_ci(2);
end
slope_ci = bootstrap_slope_ci(pooled_pred, pooled_listexp, fit_ci_opts);
if isstruct(slope_ci)
    if isfield(slope_ci, 'slope') && isfinite(slope_ci.slope)
        slope = slope_ci.slope;
    end
    if isfield(slope_ci, 'slope_ci') && numel(slope_ci.slope_ci) == 2
        slope_lo = slope_ci.slope_ci(1);
        slope_hi = slope_ci.slope_ci(2);
    end
    if isfield(slope_ci, 'p_one') && isfinite(slope_ci.p_one)
        p_one = slope_ci.p_one;
    end
end
end

function listexp_data = load_listexp_matching_assembled(S, simon2010_hemisphere)
%LOAD_LISTEXP_MATCHING_ASSEMBLED Load responses matching assembled prediction length.
dataset_id = char(S.listexp_data_id);
if startsWith(dataset_id, 'simon2010')
    mode = simon2010_hemisphere;
    if isfield(S, 'simon2010_hemisphere') && ~isempty(S.simon2010_hemisphere)
        mode = char(string(S.simon2010_hemisphere));
    end
    listexp_data = load_listexp_data('simon2010', 0, ...
        struct('simon2010_hemisphere', mode));
    listexp_data.listexp_data_id = 'simon2010';
else
    listexp_data = load_listexp_data(dataset_id, 0);
end
end

function model_ids = get_model_ids_from_saved_output(S)
    model_ids = strings(0,1);

    if isfield(S, 'error_struct_names') && iscell(S.error_struct_names)
        for k = 1:numel(S.error_struct_names)
            varname = S.error_struct_names{k};
            if isfield(S, varname) && isstruct(S.(varname)) && isfield(S.(varname), 'model_id')
                model_ids(end+1,1) = string(S.(varname).model_id); %#ok<AGROW>
            end
        end
    else
        fns = fieldnames(S);
        for k = 1:numel(fns)
            fn = fns{k};
            if startsWith(fn, 'error_') && isstruct(S.(fn)) && isfield(S.(fn), 'model_id')
                model_ids(end+1,1) = string(S.(fn).model_id); %#ok<AGROW>
            end
        end
    end

    model_ids = unique(model_ids);
end

function [r2, r2_lo, r2_hi, slope, slope_lo, slope_hi, p_one] = ...
        get_model_fit_metrics_from_saved_output(S, model_id)
    r2 = NaN;
    r2_lo = NaN;
    r2_hi = NaN;
    slope = NaN;
    slope_lo = NaN;
    slope_hi = NaN;
    p_one = NaN;

    target_error_struct = [];
    if isfield(S, 'error_struct_names') && iscell(S.error_struct_names)
        for k = 1:numel(S.error_struct_names)
            varname = S.error_struct_names{k};
            if ~isfield(S, varname) || ~isstruct(S.(varname))
                continue;
            end
            err_struct = S.(varname);
            if isfield(err_struct, 'model_id') && strcmp(string(err_struct.model_id), model_id)
                target_error_struct = err_struct;
                break;
            end
        end
    else
        fns = fieldnames(S);
        for k = 1:numel(fns)
            fn = fns{k};
            if ~startsWith(fn, 'error_') || ~isstruct(S.(fn))
                continue;
            end
            err_struct = S.(fn);
            if isfield(err_struct, 'model_id') && strcmp(string(err_struct.model_id), model_id)
                target_error_struct = err_struct;
                break;
            end
        end
    end

    if isempty(target_error_struct) || ~isfield(target_error_struct, 'error')
        return;
    end

    lm = target_error_struct.error;
    try
        r2 = lm.Rsquared.Ordinary;
    catch
        r2 = NaN;
    end

    % Bootstrap CI bounds, when present (attached by MC_vs_perceptual_data_*).
    if isfield(target_error_struct, 'r2_ci') ...
            && isstruct(target_error_struct.r2_ci) ...
            && isfield(target_error_struct.r2_ci, 'r2_ci') ...
            && numel(target_error_struct.r2_ci.r2_ci) == 2
        r2_lo = target_error_struct.r2_ci.r2_ci(1);
        r2_hi = target_error_struct.r2_ci.r2_ci(2);
    end

    try
        slope = lm.Coefficients.Estimate(2);
    catch
        slope = NaN;
    end

    if isfield(target_error_struct, 'slope_ci') ...
            && isstruct(target_error_struct.slope_ci)
        sc = target_error_struct.slope_ci;
        if isfield(sc, 'slope') && isfinite(sc.slope)
            slope = sc.slope;
        end
        if isfield(sc, 'slope_ci') && numel(sc.slope_ci) == 2
            slope_lo = sc.slope_ci(1);
            slope_hi = sc.slope_ci(2);
        end
        if isfield(sc, 'p_one') && isfinite(sc.p_one)
            p_one = sc.p_one;
        end
    end
end

function [ref_idx, ref_id] = pick_reference_model_index(r2_col, all_model_ids, S_or_mask)
%PICK_REFERENCE_MODEL_INDEX Best point R^2 among models with saved predictions.
% On ties, pick the first candidate in all_model_ids order.
% S_or_mask is either a saved-output struct S, or a logical mask (nModels x 1)
% indicating which models have usable pooled predictions.
    ref_idx = [];
    ref_id = "";
    r2_col = r2_col(:);
    valid = isfinite(r2_col);
    if ~any(valid)
        return;
    end
    if isstruct(S_or_mask)
        pred_ok = false(numel(all_model_ids), 1);
        for i = 1:numel(all_model_ids)
            pred_ok(i) = has_saved_model_predictions(S_or_mask, all_model_ids(i));
        end
    else
        pred_ok = logical(S_or_mask(:));
    end
    candidate_idx = find(valid & pred_ok);
    if isempty(candidate_idx)
        return;
    end
    [~, sort_ord] = sort(r2_col(candidate_idx), 'descend');
    ref_idx = candidate_idx(sort_ord(1));
    ref_id = all_model_ids(ref_idx);
end

function mask = build_pooled_prediction_availability_mask(pooled_preds, n_expected)
    mask = false(numel(pooled_preds), 1);
    for i = 1:numel(pooled_preds)
        mask(i) = ~isempty(pooled_preds{i}) && numel(pooled_preds{i}) == n_expected;
    end
end

function tf = has_saved_model_predictions(S, model_id)
    try
        get_saved_model_predictions(S, model_id);
        tf = true;
    catch
        tf = false;
    end
end

function p_fdr = apply_fdr_bh_column(p_col, ref_idx)
%APPLY_FDR_BH_COLUMN Benjamini-Hochberg FDR on challenger p-values only.
    p_fdr = nan(size(p_col));
    challenger_idx = find((1:numel(p_col))' ~= ref_idx & isfinite(p_col(:)));
    if isempty(challenger_idx)
        return;
    end
    p_sub = p_col(challenger_idx);
    m = numel(p_sub);
    [p_sorted, sort_ord] = sort(p_sub);
    ranks = (1:m)';
    q = p_sorted .* m ./ ranks;
    q = flipud(cummin(flipud(q)));
    q_inv = nan(m, 1);
    q_inv(sort_ord) = q;
    p_fdr(challenger_idx) = min(q_inv, 1);
end

function fig = plot_model_r2_comparison(model_ids, dataset_labels, R2, R2lo, R2hi, sort_by, sofa_title, fig_w_pt)
%PLOT_MODEL_R2_COMPARISON Faceted horizontal R^2 plot with bootstrap CIs.

    if nargin < 8 || isempty(fig_w_pt)
        widths = latex_figure_widths();
        fig_w_pt = widths.paper_width_pt;
    end

    pub_fs = grid_publication_font_sizes();
    nModels = size(R2, 1);
    nSeries = size(R2, 2);
    if numel(model_ids) ~= nModels || numel(dataset_labels) ~= nSeries
        error('plot_model_r2_comparison:Size', ...
            'model_ids (%d), R2 rows (%d), and dataset_labels (%d) must align.', ...
            numel(model_ids), nModels, nSeries);
    end

    model_ids = model_ids(:);
    dataset_labels = dataset_labels(:);

    switch sort_by
        case 'combined'
            sort_scores = R2(:, end);
        otherwise
            sort_scores = R2(:, end);
    end
    [~, sortIdx] = sort(sort_scores, 'descend', 'MissingPlacement', 'last');
    model_ids = model_ids(sortIdx);
    R2 = R2(sortIdx, :);
    R2lo = R2lo(sortIdx, :);
    R2hi = R2hi(sortIdx, :);

    [x_lo, x_hi] = shared_r2_xlim(R2, R2lo, R2hi);
    [xTicksMajor, xTicksMinor] = build_r2_axis_ticks(x_lo, x_hi);

    nc = 3;
    nr = 2;

    % Size at LaTeX target width before drawing so export does not squash fonts.
    pts_per_model = 9;
    tile_pad_pt = 20;
    fig_h_pt = nr * (nModels * pts_per_model + tile_pad_pt) + 24;
    fig_h_pt = max(fig_h_pt, fig_w_pt * nr / max(nc, 1) * 0.72);
    fig = figure('Color', 'w', 'Units', 'points', ...
        'Position', [36, 36, fig_w_pt, fig_h_pt]);
    tl = tiledlayout(fig, nr, nc, 'TileSpacing', 'compact', 'Padding', 'compact');

    point_color = [0.15, 0.35, 0.65];
    tile_axes = gobjects(nSeries, 1);

    for j = 1:nSeries
        ax = nexttile(tl);
        tile_axes(j) = ax;
        hold(ax, 'on');

        x = R2(:, j);
        lo = R2lo(:, j);
        hi = R2hi(:, j);
        y = (1:nModels)';
        valid = ~isnan(x);
        has_ci = valid & ~isnan(lo) & ~isnan(hi);
        marker_only = valid & ~has_ci;

        if any(has_ci)
            xneg = x(has_ci) - lo(has_ci);
            xpos = hi(has_ci) - x(has_ci);
            errorbar(ax, x(has_ci), y(has_ci), xneg, xpos, 'horizontal', ...
                'o', 'Color', point_color, 'MarkerFaceColor', point_color, ...
                'LineWidth', 0.75, 'MarkerSize', 4, 'CapSize', 3);
        end
        if any(marker_only)
            plot(ax, x(marker_only), y(marker_only), 'o', ...
                'Color', point_color, 'MarkerFaceColor', point_color, ...
                'MarkerSize', 4, 'LineStyle', 'none');
        end

        yticks(ax, 1:nModels);
        yticklabels(ax, cellfun(@format_model_plot_label, cellstr(model_ids), ...
            'UniformOutput', false));
        ax.YAxis.TickLabelInterpreter = 'none';
        ax.YDir = 'reverse';
        title(ax, char(dataset_labels(j)), 'Interpreter', 'none', ...
            'FontWeight', 'normal', 'FontSize', pub_fs.tile_title);
        grid(ax, 'on');
        ax.XGrid = 'on';
        ax.YGrid = 'off';
        ax.Box = 'on';
        ax.FontSize = pub_fs.tick;
        xlim(ax, [x_lo, x_hi]);
        xticks(ax, xTicksMajor);
        ax.XMinorTick = 'on';
        ax.XMinorGrid = 'on';
        if isprop(ax.XAxis, 'MinorTickValues')
            ax.XAxis.MinorTickValues = xTicksMinor;
        end
        ylim(ax, [0.5, nModels + 0.5]);
        hold(ax, 'off');
    end

    xlabel(tl, 'R²', 'Interpreter', 'none', 'FontSize', pub_fs.axis_label);
    % Y-axis labels on the left column only.
    for j = 1:nSeries
        ax = tile_axes(j);
        col = mod(j - 1, nc) + 1;
        if col ~= 1
            ax.YTickLabel = {};
        end
    end
end

function [xTicksMajor, xTicksMinor] = build_r2_axis_ticks(xLo, xHi)
%BUILD_R2_AXIS_TICKS Return major 0.1 ticks and minor 0.05 ticks.
    majorStep = 0.1;
    minorStep = 0.05;
    tol = 1e-9;

    majorStart = ceil((xLo - tol) / majorStep) * majorStep;
    majorEnd = floor((xHi + tol) / majorStep) * majorStep;
    xTicksMajor = majorStart:majorStep:majorEnd;
    xTicksMajor = round(xTicksMajor, 10);

    minorStart = ceil((xLo - tol) / minorStep) * minorStep;
    minorEnd = floor((xHi + tol) / minorStep) * minorStep;
    xTicksMinor = minorStart:minorStep:minorEnd;
    xTicksMinor = round(xTicksMinor, 10);

    isMajorMinor = ismembertol(xTicksMinor, xTicksMajor, tol, 'DataScale', 1);
    xTicksMinor = xTicksMinor(~isMajorMinor);
end

function [x_lo, x_hi] = shared_r2_xlim(R2, R2lo, R2hi)
    all_lo = R2lo(:);
    all_hi = R2hi(:);
    all_r2 = R2(:);
    x_min = min([all_lo(~isnan(all_lo)); all_r2(~isnan(all_r2))]);
    x_max = max([all_hi(~isnan(all_hi)); all_r2(~isnan(all_r2))]);
    if isempty(x_min) || isnan(x_min)
        x_min = 0;
    end
    if isempty(x_max) || isnan(x_max)
        x_max = 1;
    end
    pad = 0.05 * max(x_max - x_min, 0.1);
    x_lo = max(0, x_min - pad);
    if x_max > 1
        x_hi = x_max + pad;
    else
        x_hi = min(1, x_max + pad);
    end
    if x_hi <= x_lo
        x_hi = x_lo + 0.1;
    end
end

function write_model_r2_latex_table(filename, model_ids, dataset_names, ...
        R2, combined_r2, sig_vs_best, ref_model_col, time_per_stim_s)
%WRITE_MODEL_R2_LATEX_TABLE Write manuscript LaTeX table of R^2 values.
%
%   Rows are sorted by decreasing combined R^2. Model row labels match the
%   R^2 comparison figures (format_model_plot_label). Dataset column headers
%   use listexp_data_id strings from the saved run files. The final column
%   reports trial-weighted mean execution time per stimulus (seconds).
%   Entries that differ significantly from the column reference (FDR < 0.05)
%   are set in boldface.

    model_ids = string(model_ids(:));
    dataset_names = string(dataset_names(:));
    time_per_stim_s = time_per_stim_s(:);
    nModels = numel(model_ids);
    nDatasets = numel(dataset_names);

    if numel(time_per_stim_s) ~= nModels
        error('write_model_r2_latex_table:Size', ...
            'time_per_stim_s (%d) must match number of models (%d).', ...
            numel(time_per_stim_s), nModels);
    end

    has_combined = any(isfinite(combined_r2));
    nCols = nDatasets + has_combined;

    if has_combined
        R2_all = [R2, combined_r2];
        col_labels = [dataset_names; "Combined"];
    else
        R2_all = R2;
        col_labels = dataset_names;
    end
    col_labels = col_labels(:)';

    if size(sig_vs_best, 2) >= nCols
        sig_all = sig_vs_best(:, 1:nCols);
    else
        sig_all = false(nModels, nCols);
    end

    if has_combined
        [~, sort_idx] = sort(combined_r2, 'descend', 'MissingPlacement', 'last');
    else
        sort_idx = (1:nModels)';
    end

    ref_ids = strings(1, nCols);
    for j = 1:nCols
        if size(ref_model_col, 1) >= 1 && size(ref_model_col, 2) >= j
            ref_ids(j) = string(ref_model_col(1, j));
        end
    end

    col_spec = ['l', repmat('c', 1, nCols + 1)];
    header_cells = ["Model", col_labels, "Time/stimulus (s)"];
    header_line = strjoin(cellstr(escape_latex_text(header_cells)), ' & ');

    body_lines = strings(nModels, 1);
    for iSort = 1:nModels
        i = sort_idx(iSort);
        row_parts = cell(1, nCols + 2);
        row_parts{1} = char(format_model_latex_label(model_ids(i)));
        for j = 1:nCols
            row_parts{j + 1} = format_r2_latex_cell(R2_all(i, j), sig_all(i, j));
        end
        row_parts{nCols + 2} = format_time_latex_cell(time_per_stim_s(i));
        body_lines(iSort) = strjoin(row_parts, ' & ');
    end

    ref_parts = strings(1, nCols);
    for j = 1:nCols
        ref_label = ref_ids(j);
        if strlength(ref_label) == 0
            ref_label = "?";
        end
        ref_parts(j) = escape_latex_text(col_labels(j)) + ": " + ...
            format_model_latex_label(ref_label);
    end
    ref_clause = strjoin(cellstr(ref_parts), "; ");

    lines = strings(0, 1);
    lines(end+1) = '\begin{table*}[t]'; %#ok<AGROW>
    lines(end+1) = '  \centering'; %#ok<AGROW>
    lines(end+1) = sprintf(['  \\caption{Coefficient of determination ($R^2$) for the ' ...
        'linear fit between model-estimated and perceived lateral angles, ' ...
        'evaluated on %d listening-test dataset(s)%s. Models are ' ...
        'sorted by decreasing $R^2$ on the combined data. Within each column, ' ...
        'paired bootstrap comparisons against the best-performing model in that ' ...
        'column were corrected for multiple comparisons (Benjamini--Hochberg FDR); ' ...
        'entries in \\textbf{bold} differ significantly from the column reference ' ...
        '($p_\\mathrm{FDR}<0.05$). The last column gives the trial-weighted mean ' ...
        'execution time per stimulus (seconds) pooled across datasets. ' ...
        'Column references: %s.}'], ...
        nDatasets, ternary_latex(has_combined, ' and a pooled \emph{Combined} set', ''), ...
        char(ref_clause)); %#ok<AGROW>
    lines(end+1) = '  \label{tab:model_r2}'; %#ok<AGROW>
    lines(end+1) = sprintf('  \\begin{tabular}{%s}', col_spec); %#ok<AGROW>
    lines(end+1) = '    \hline'; %#ok<AGROW>
    lines(end+1) = ['    ' char(header_line) ' \\']; %#ok<AGROW>
    lines(end+1) = '    \hline'; %#ok<AGROW>
    for iSort = 1:nModels
        lines(end+1) = ['    ' char(body_lines(iSort)) ' \\']; %#ok<AGROW>
    end
    lines(end+1) = '    \hline'; %#ok<AGROW>
    lines(end+1) = '  \end{tabular}'; %#ok<AGROW>
    lines(end+1) = '\end{table*}'; %#ok<AGROW>

    fid = fopen(filename, 'w');
    if fid < 0
        error('write_model_r2_latex_table:FileOpen', ...
            'Could not open LaTeX output file: %s', filename);
    end
    cleaner = onCleanup(@() fclose(fid)); %#ok<NASGU>
    fprintf(fid, '%s\n', lines);
end

function write_model_runtime_latex_table(filename, model_ids, time_per_stim_s)
%WRITE_MODEL_RUNTIME_LATEX_TABLE Write LaTeX table of mean runtime per trial.
%
%   Rows are sorted by increasing trial-weighted mean execution time (seconds).
%   Model row labels match the R^2 comparison figures (format_model_plot_label).

    model_ids = string(model_ids(:));
    time_per_stim_s = time_per_stim_s(:);
    nModels = numel(model_ids);

    if numel(time_per_stim_s) ~= nModels
        error('write_model_runtime_latex_table:Size', ...
            'time_per_stim_s (%d) must match number of models (%d).', ...
            numel(time_per_stim_s), nModels);
    end

    [~, sort_idx] = sort(time_per_stim_s, 'ascend', 'MissingPlacement', 'last');

    header_line = strjoin(cellstr(escape_latex_text( ...
        ["Model", "Mean time per trial (s)"])), ' & ');

    body_lines = strings(nModels, 1);
    for iSort = 1:nModels
        i = sort_idx(iSort);
        row_parts = { ...
            char(format_model_latex_label(model_ids(i))), ...
            format_time_latex_cell(time_per_stim_s(i))};
        body_lines(iSort) = strjoin(row_parts, ' & ');
    end

    lines = strings(0, 1);
    lines(end+1) = '\begin{table}[t]'; %#ok<AGROW>
    lines(end+1) = '  \centering'; %#ok<AGROW>
    lines(end+1) = ['  \caption{Trial-weighted mean execution time per stimulus ' ...
        '(seconds) for each model, pooled across datasets. Models are sorted ' ...
        'by increasing runtime. Values below 0.001~s are reported as ' ...
        '$<$0.001.}']; %#ok<AGROW>
    lines(end+1) = '  \label{tab:model_runtime}'; %#ok<AGROW>
    lines(end+1) = '  \begin{tabular}{lc}'; %#ok<AGROW>
    lines(end+1) = '    \hline'; %#ok<AGROW>
    lines(end+1) = ['    ' char(header_line) ' \\']; %#ok<AGROW>
    lines(end+1) = '    \hline'; %#ok<AGROW>
    for iSort = 1:nModels
        lines(end+1) = ['    ' char(body_lines(iSort)) ' \\']; %#ok<AGROW>
    end
    lines(end+1) = '    \hline'; %#ok<AGROW>
    lines(end+1) = '  \end{tabular}'; %#ok<AGROW>
    lines(end+1) = '\end{table}'; %#ok<AGROW>

    fid = fopen(filename, 'w');
    if fid < 0
        error('write_model_runtime_latex_table:FileOpen', ...
            'Could not open LaTeX output file: %s', filename);
    end
    cleaner = onCleanup(@() fclose(fid)); %#ok<NASGU>
    fprintf(fid, '%s\n', lines);
end

function out = format_model_latex_label(model_id)
%FORMAT_MODEL_LATEX_LABEL Figure-style model label, escaped for LaTeX.
    out = escape_latex_text(format_model_plot_label(model_id));
end

function out = escape_latex_text(txt)
%ESCAPE_LATEX_TEXT Escape special characters for LaTeX tabular text.
    if isstring(txt) && isscalar(txt)
        txt = char(txt);
    elseif isstring(txt)
        out = strings(size(txt));
        for k = 1:numel(txt)
            out(k) = string(escape_latex_text(char(txt(k))));
        end
        return;
    end
    txt = char(txt);
    txt = strrep(txt, '\\', '\textbackslash{}');
    txt = strrep(txt, '_', '\_');
    txt = strrep(txt, '%', '\%');
    txt = strrep(txt, '&', '\&');
    txt = strrep(txt, '#', '\#');
    txt = strrep(txt, '{', '\{');
    txt = strrep(txt, '}', '\}');
    out = string(txt);
end

function cell_txt = format_time_latex_cell(time_s)
    if ~isfinite(time_s)
        cell_txt = '---';
        return;
    end
    if time_s > 0 && time_s < 0.001
        cell_txt = '$<$0.001';
    elseif time_s >= 100
        cell_txt = sprintf('%.2e', time_s);
    else
        cell_txt = sprintf('%.3f', time_s);
    end
end

function cell_txt = format_r2_latex_cell(r2, bold)
    if ~isfinite(r2)
        cell_txt = '---';
        return;
    end
    txt = sprintf('%.3f', r2);
    if bold
        cell_txt = ['\textbf{' txt '}'];
    else
        cell_txt = txt;
    end
end

function out = ternary_latex(cond, if_true, if_false)
    if cond
        out = if_true;
    else
        out = if_false;
    end
end
