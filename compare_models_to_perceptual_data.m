% COMPARE_MODELS_TO_PERCEPTUAL_DATA
% Compare lateral-angle model estimates against perceptual (listening
% experiment) data and produce the model-fit figures of the paper.
%
% With the default configuration (run_mode = 'combined_from_cache',
% run_multi_hrtf = true) this script produces:
%
%   figures/model_summary_simon2010_desena2013_frank2013_ramirez2024_llado2026.pdf
%       Combined-dataset fit: every model's predictions against the pooled
%       perceptual responses of the five datasets, with R^2 / slope CIs.
%   figures/model_summary_off_centre.pdf
%       Same, restricted to the off-centre listening positions of desena2013,
%       frank2013 and llado2026 (P1-P3).
%
% Model predictions are averaged over the HRTFs in multi_hrtf_sofa_dir
% (8 SOFA files: SONICOM P0001/P0003/P0005/P0006 and ARI nh1059/nh1188/
% nh1189/nh1190). Run download_dependencies from the repository root to
% fetch those HRTFs and the publicly available perceptual datasets.
% Cached per-model outputs live in model_output_dir; see README.md for
% how to obtain them or recompute them (run_mode = 'combined_recompute').
%
% Heavy model maths lives in models/<model>/eval_<model>.m; this script only
% orchestrates configuration, stimulus generation, model dispatch, and I/O.
%
% Run modes (run_mode):
%   'combined_from_cache' Load cached per-dataset outputs and pool them (default).
%   'combined_recompute'  Recompute each dataset in combined_dataset_ids, then
%                         pool predictions for a combined fit.
%   'single'              Evaluate one dataset (listexp_data_id) and plot/save.
%                         Also used internally by 'combined_recompute'.
%
% Machine-specific locations (AMT, PrecSep, Python environments, WaveLoc,
% Docker) are read from local_paths.m; copy local_paths_template.m to
% local_paths.m and edit it before running. See README.md.
%
% AUTHOR: Pedro Llado. Optimised and refactored by Rapolas Daugintis.

setup_paths();

%% Configuration

% Model run toggles.
run_lindemann1986 = true;
run_breebaart2001 = true;
run_faller2004 = true;    % requires the PrecSep toolbox
run_may2011 = true;
run_dietz2011 = true;
run_takanen2013 = true;   % requires a Python environment (verhulst2012 periphery)
run_llado2025 = true;
run_extended_re = true;   % kurz2017, stitt2016, rE (geometry only, no HRTF)
run_saddler2024 = true;   % requires the phaselocknet Python environment (slow)
run_wang2026 = true;      % requires the ei_yang Python environment (slow)
run_vecchiotti2019 = true; % requires WaveLoc via Docker (Vecchiotti et al., 2019)

% Output caching.
load_existing_model_output_data = true; % true: load cached outputs, skip recomputation
save_model_output_data = true;         % true: save outputs after recomputation
recompute_model_ids = {}; % e.g. {'llado2025'} forces rerun even when cached
model_output_dir = 'model_output_data';
use_parallel = true; % false: serial loops for debugging (no parpool / parfor workers)
run_mode = 'combined_from_cache';       % 'combined_from_cache' | 'combined_recompute' | 'single'
combined_dataset_ids = {'simon2010', 'desena2013', 'frank2013', 'ramirez2024', 'llado2026'};

% Dataset to evaluate in 'single' mode.
% Supported ids: 'desena2013', 'simon2010', 'llado2026', 'ramirez2024', 'frank2013'.
listexp_data_id = 'llado2026';
flag_plot_listexp = 0;

% Simon (2010) analysis/plot view (ignored for other datasets).
% Models always simulate and cache directed (separate) L+R conditions under
% the cache id 'simon2010'. This flag only selects the fit/plot view:
%   'fold_lr'  - paper-style: pool mirrored L+R responses (native fold loader)
%                and trial-weight-average mirrored predictions
%   'separate' - keep right-side pairs as separate conditions (axes extend)
% Keep in sync with simon2010_hemisphere in build_model_output_r2_table.m.
simon2010_hemisphere = 'separate';

% Frank (2013) stimulus: false = three 400 ms bursts with 200 ms silence (thesis
% protocol); true = one 400 ms burst only.
frank2013_single_burst = true;

% Plot axis behaviour: when true, every tile's xlim equals its ylim (square
% plot, y=x bisects the axes). When false, x and y scale independently but
% stay consistent across all tiles in a grid figure.
plot_equal_xy_limits = false;

% Figure export for LaTeX manuscript (vector PDF, paper-width figures).
save_figures = true;
figure_output_dir = 'figures';
latex_fig_widths = latex_figure_widths();
figure_save_opts = struct( ...
    'enabled', save_figures, ...
    'output_dir', figure_output_dir, ...
    'max_width_pt', latex_fig_widths.paper_width_pt);

% R^2 / slope bootstrap confidence-interval options. The resampling scheme per
% dataset is defined in load_listexp_data (nested for desena2013/llado2026,
% condition/case otherwise and for the pooled combined fit).
compute_r2_ci = true;
compute_slope_ci = true;
r2_ci_nboot = 10000;
r2_ci_level = 0.95;
r2_ci_seed = 42;

% Also plot one pooled off-centre-only model grid in combined runs
% (desena2013, llado2026, frank2013 intersected with combined_dataset_ids).
% llado2026 off-centre = P1+P2+P3. PDF: model_summary_off_centre.pdf.
plot_off_centre_only = true;

% HRTFs. Multi-HRTF mode (used for the paper) loops over every .sofa file in
% multi_hrtf_sofa_dir and aggregates mean/SEM of the model estimates. Populate
% the folder with aux_data/HRTFs/download_hrtfs.m before running.
run_multi_hrtf = true;
multi_hrtf_sofa_dir = 'aux_data/HRTFs/collection/';
multi_hrtf_sofa_names = {};
% Single-HRTF mode (run_multi_hrtf = false): one SOFA file, name without the
% extension (also used for template-cache naming).
sofa_name = 'P0001_FreeFieldCompMinPhase_48kHz';
sofa_dir = 'aux_data/HRTFs/collection/';

% Python environments (see local_paths_template.m). Only required when the
% corresponding models are (re)computed; not needed to plot from cache.
lp = local_paths();
pyFolder = string(lp.phaselocknet_dir);          % saddler2024 (phaselocknet)
venvPython = string(lp.phaselocknet_python);     % saddler2024 interpreter
amt_python = string(lp.amt_python);              % takanen2013 (AMT verhulst2012 periphery)
repo_root = fileparts(mfilename("fullpath"));
wang2026_pyFolder = fullfile(repo_root, "models", "wang2026");
wang2026_venvPython = string(lp.ei_yang_python); % wang2026 (ei_yang)
wang2026_model_filename = "P3.keras";  % Yang confirmed that P3 with ReTanh activation should be used.
% The models are mislabelled in the ei_yang repository, compared to the paper
% (P3.keras is equivalent to the P1 model in the IEEE Transactions paper).

% Optional runtime overrides for isolated subprocess execution.
env_run_mode = getenv('MC_RUN_MODE_OVERRIDE');
if ~isempty(env_run_mode)
    run_mode = env_run_mode;
end
env_dataset_id = getenv('MC_LISTEXP_DATASET_OVERRIDE');
if ~isempty(env_dataset_id)
    listexp_data_id = env_dataset_id;
end
env_simon_hemisphere = getenv('MC_SIMON2010_HEMISPHERE_OVERRIDE');
if ~isempty(env_simon_hemisphere)
    simon2010_hemisphere = env_simon_hemisphere;
end
env_load_cached = getenv('MC_LOAD_EXISTING_OVERRIDE');
if ~isempty(env_load_cached)
    load_existing_model_output_data = strcmpi(env_load_cached, 'true');
end
env_save_output = getenv('MC_SAVE_OUTPUT_OVERRIDE');
if ~isempty(env_save_output)
    save_model_output_data = strcmpi(env_save_output, 'true');
end
env_model_output_dir = getenv('MC_MODEL_OUTPUT_DIR_OVERRIDE');
if ~isempty(env_model_output_dir)
    model_output_dir = env_model_output_dir;
end
env_recompute_models = getenv('MC_RECOMPUTE_MODELS_OVERRIDE');
if ~isempty(env_recompute_models)
    recompute_model_ids = strtrim(strsplit(env_recompute_models, ','));
end
recompute_model_ids = normalize_recompute_model_ids(recompute_model_ids);
env_skip_plot = getenv('MC_SKIP_PLOT_OVERRIDE');
skip_plot = strcmpi(env_skip_plot, 'true');
% Multi-HRTF overrides are only for combined_recompute subprocesses (which
% always set MC_LISTEXP_DATASET_OVERRIDE). Ignore stale values on interactive
% runs so a prior subprocess cannot force multi-HRTF mode.
is_subprocess_run = ~isempty(getenv('MC_LISTEXP_DATASET_OVERRIDE'));
if is_subprocess_run
    env_run_multi_hrtf = getenv('MC_RUN_MULTI_HRTF_OVERRIDE');
    if ~isempty(env_run_multi_hrtf)
        run_multi_hrtf = strcmpi(env_run_multi_hrtf, 'true');
    end
    env_multi_hrtf_dir = getenv('MC_MULTI_HRTF_SOFA_DIR_OVERRIDE');
    if ~isempty(env_multi_hrtf_dir)
        multi_hrtf_sofa_dir = env_multi_hrtf_dir;
    end
else
    setenv('MC_RUN_MULTI_HRTF_OVERRIDE', '');
    setenv('MC_MULTI_HRTF_SOFA_DIR_OVERRIDE', '');
end

if run_multi_hrtf
    sofa_name = derive_multi_hrtf_cache_label(multi_hrtf_sofa_dir);
    assembly_multi_hrtf_sofa_dir = multi_hrtf_sofa_dir;
else
    assembly_multi_hrtf_sofa_dir = '';
end

rng('default');
rng(13121);

%% Load listening experiment data
% Simon2010: always load directed (separate) conditions for simulation/cache.
% simon2010_hemisphere selects the fit/plot view after predictions exist.
simon2010_plot_hemisphere = simon2010_hemisphere;
load_opts = struct();
if strcmp(listexp_data_id, 'simon2010') || strcmp(listexp_data_id, 'simon2010_separate')
    if strcmp(listexp_data_id, 'simon2010_separate')
        simon2010_plot_hemisphere = 'separate';
    end
    load_opts.simon2010_hemisphere = 'separate';
end
listexp_data = load_listexp_data(listexp_data_id, flag_plot_listexp, load_opts);
% Model dispatch always uses the base dataset id (stimuli / sign correction).
if startsWith(listexp_data_id, 'simon2010')
    listexp_data_id = 'simon2010';
end
listexp_data.listexp_data_id = listexp_data_id;
% Single simon2010 cache namespace (directed/separate conditions).
cache_dataset_id = listexp_data_id;

% Cache filename includes both dataset and HRTF template name.
safe_sofa_name = regexprep(sofa_name, '[^A-Za-z0-9_-]', '_');
safe_listexp_data_id = regexprep(cache_dataset_id, '[^A-Za-z0-9_-]', '_');

enabled_model_ids = get_enabled_model_ids_from_flags( ...
    run_lindemann1986, run_breebaart2001, run_faller2004, run_may2011, ...
    run_dietz2011, run_takanen2013, run_llado2025, run_extended_re, ...
    run_saddler2024, run_wang2026, run_vecchiotti2019);
geometry_model_ids_local = geometry_model_ids();
hrtf_dependent_model_ids = setdiff(enabled_model_ids, geometry_model_ids_local, 'stable');

%% Combined run modes (pool several datasets into one fit)
if ~strcmp(run_mode, 'single')
    if strcmp(run_mode, 'combined_recompute')
        % Subruns execute this script in the base workspace with
        % MC_SKIP_PLOT_OVERRIDE=true, which overwrites skip_plot. Preserve the
        % parent run's plotting intent for the pooled figures below.
        parent_skip_plot = skip_plot;

        script_path = [mfilename('fullpath') '.m'];
        combined_recompute_temp_dir = '';
        recompute_output_dir = model_output_dir;
        if ~save_model_output_data
            combined_recompute_temp_dir = tempname;
            mkdir(combined_recompute_temp_dir);
            recompute_output_dir = combined_recompute_temp_dir;
        end
        cleanup_combined_temp = onCleanup(@() cleanup_combined_recompute_temp(combined_recompute_temp_dir));

        for dsIdx = 1:numel(combined_dataset_ids)
            listexp_data_id = combined_dataset_ids{dsIdx};
            fprintf('Recomputing dataset in current MATLAB session: %s\n', listexp_data_id);

            setenv('MC_RUN_MODE_OVERRIDE', 'single');
            setenv('MC_LISTEXP_DATASET_OVERRIDE', listexp_data_id);
            setenv('MC_SIMON2010_HEMISPHERE_OVERRIDE', simon2010_plot_hemisphere);
            if isempty(recompute_model_ids)
                setenv('MC_LOAD_EXISTING_OVERRIDE', 'false');
                setenv('MC_RECOMPUTE_MODELS_OVERRIDE', '');
            else
                setenv('MC_LOAD_EXISTING_OVERRIDE', 'true');
                setenv('MC_RECOMPUTE_MODELS_OVERRIDE', strjoin(recompute_model_ids, ','));
            end
            setenv('MC_SAVE_OUTPUT_OVERRIDE', 'true');
            setenv('MC_MODEL_OUTPUT_DIR_OVERRIDE', recompute_output_dir);
            setenv('MC_SKIP_PLOT_OVERRIDE', 'true');
            if run_multi_hrtf
                setenv('MC_RUN_MULTI_HRTF_OVERRIDE', 'true');
                setenv('MC_MULTI_HRTF_SOFA_DIR_OVERRIDE', multi_hrtf_sofa_dir);
            else
                setenv('MC_RUN_MULTI_HRTF_OVERRIDE', 'false');
                setenv('MC_MULTI_HRTF_SOFA_DIR_OVERRIDE', '');
            end
            cleanup_env = onCleanup(@() clear_combined_recompute_overrides());
            run(script_path);
            clear cleanup_env;
        end

        skip_plot = parent_skip_plot;
    elseif strcmp(run_mode, 'combined_from_cache')
        if ~isempty(recompute_model_ids)
            script_path = [mfilename('fullpath') '.m'];
            run_selective_recompute_for_datasets( ...
                script_path, combined_dataset_ids, model_output_dir, ...
                recompute_model_ids, run_multi_hrtf, multi_hrtf_sofa_dir, ...
                simon2010_plot_hemisphere);
        end
    else
        error('Unsupported run_mode: %s', run_mode);
    end

    if strcmp(run_mode, 'combined_recompute') && ~save_model_output_data
        combined_load_dir = recompute_output_dir;
    else
        combined_load_dir = model_output_dir;
    end

    combined_results = cell(1, numel(combined_dataset_ids));
    for dsIdx = 1:numel(combined_dataset_ids)
        ds_cache_id = combined_dataset_ids{dsIdx};
        if strcmp(ds_cache_id, 'simon2010_separate')
            ds_cache_id = 'simon2010';
        end
        assemble_opts = { ...
            'model_ids', enabled_model_ids, ...
            'multi_hrtf_sofa_dir', assembly_multi_hrtf_sofa_dir, ...
            'compute_r2_ci', compute_r2_ci, ...
            'compute_slope_ci', compute_slope_ci, ...
            'fit_ci_opts', struct('n_boot', r2_ci_nboot, ...
            'ci_level', r2_ci_level, 'seed', r2_ci_seed)};
        if strcmp(ds_cache_id, 'simon2010')
            assemble_opts = [assemble_opts, ...
                {'simon2010_hemisphere', simon2010_plot_hemisphere}]; %#ok<AGROW>
        end
        combined_results{dsIdx} = assemble_model_output( ...
            combined_load_dir, ds_cache_id, sofa_name, assemble_opts{:});
    end

    combined_model_ids = get_union_model_ids(combined_results);
    errors_to_plot = cell(1, numel(combined_model_ids));
    for midx = 1:numel(combined_model_ids)
        model_id = combined_model_ids{midx};
        pooled_pred = [];
        pooled_resp = [];
        pooled_dataset_idx = [];
        pooled_est_yerr = [];
        for dsIdx = 1:numel(combined_results)
            [est_pred, est_resp] = get_saved_prediction_and_response_for_model( ...
                combined_results{dsIdx}, model_id, simon2010_plot_hemisphere);
            est_sem = get_saved_model_sem(combined_results{dsIdx}, model_id);
            pooled_pred = [pooled_pred; est_pred(:)]; %#ok<AGROW>
            pooled_resp = [pooled_resp; est_resp(:)]; %#ok<AGROW>
            pooled_dataset_idx = [pooled_dataset_idx; dsIdx * ones(numel(est_pred), 1)]; %#ok<AGROW>
            if ~isempty(est_sem)
                pooled_est_yerr = [pooled_est_yerr; est_sem(:)]; %#ok<AGROW>
            end
        end

        pooled_listexp = struct('avgResponseVector', pooled_resp);
        this_error = struct();
        this_error.error = func_errormetrics(pooled_pred, pooled_listexp);
        this_error.model_id = model_id;
        this_error.dataset_idx = pooled_dataset_idx;
        % Pooled datasets mix native resampling units, so use a condition/case
        % bootstrap over the pooled (response, prediction) pairs.
        fit_ci_opts = struct('n_boot', r2_ci_nboot, 'ci_level', r2_ci_level, ...
            'seed', r2_ci_seed);
        if compute_r2_ci || compute_slope_ci
            pooled_listexp.r2_resample = struct('unit', 'condition');
        end
        if compute_r2_ci
            this_error.r2_ci = bootstrap_r2_ci(pooled_pred, pooled_listexp, fit_ci_opts);
        end
        if compute_slope_ci
            this_error.slope_ci = bootstrap_slope_ci(pooled_pred, pooled_listexp, fit_ci_opts);
        end
        if ~isempty(pooled_est_yerr) && numel(pooled_est_yerr) == numel(pooled_pred)
            this_error.est_yerr = pooled_est_yerr;
        end
        errors_to_plot{midx} = this_error;
    end

    combined_label = strjoin(combined_dataset_ids, '_');

    % All pooled error structs share the same dataset_idx ordering, so a
    % single color_info works for every tile in the grid.
    if ~isempty(errors_to_plot)
        combined_color_info = build_combined_color_info_for_datasets( ...
            combined_dataset_ids, errors_to_plot{1}.dataset_idx, ...
            simon2010_plot_hemisphere);
    else
        combined_color_info = [];
    end
    if ~skip_plot
        combined_axis = struct('lim', [-100, 100], ...
            'ticks', [-90, -45, 0, 45, 90]);
        plot_estimatederror_grid(errors_to_plot, combined_label, combined_color_info, ...
            plot_equal_xy_limits, figure_save_opts, combined_axis, false);
    end

    if plot_off_centre_only && ~skip_plot
        fit_ci_opts_off = struct('n_boot', r2_ci_nboot, ...
            'ci_level', r2_ci_level, 'seed', r2_ci_seed);
        run_combined_off_centre_plot( ...
            combined_results, combined_dataset_ids, ...
            compute_r2_ci, compute_slope_ci, fit_ci_opts_off, ...
            skip_plot, plot_equal_xy_limits, figure_save_opts, ...
            simon2010_plot_hemisphere);
    end
    return
end

%% Resolve per-model cache and determine what to compute
if run_multi_hrtf
    [sofa_paths, multi_hrtf_sofa_names] = list_sofa_files_in_folder(multi_hrtf_sofa_dir);
    hrtf_names = multi_hrtf_sofa_names;
else
    sofa_paths = {fullfile(sofa_dir, [sofa_name '.sofa'])};
    hrtf_names = {sofa_name};
end

[models_to_compute, models_from_cache, all_fully_cached] = resolve_models_to_compute( ...
    model_output_dir, cache_dataset_id, hrtf_names, enabled_model_ids, ...
    load_existing_model_output_data, recompute_model_ids);

fit_ci_opts = struct('n_boot', r2_ci_nboot, 'ci_level', r2_ci_level, 'seed', r2_ci_seed);

if all_fully_cached && load_existing_model_output_data
  loaded_data = assemble_model_output(model_output_dir, cache_dataset_id, sofa_name, ...
      'model_ids', enabled_model_ids, ...
      'multi_hrtf_sofa_dir', assembly_multi_hrtf_sofa_dir, ...
      'compute_r2_ci', compute_r2_ci, ...
      'compute_slope_ci', compute_slope_ci, ...
      'fit_ci_opts', fit_ci_opts, ...
      'simon2010_hemisphere', simon2010_plot_hemisphere);
  plot_assembled_single_dataset_output(loaded_data, skip_plot, plot_equal_xy_limits, ...
      figure_save_opts, simon2010_plot_hemisphere);
  return;
end

%% Parallel pool and Python environment for workers
% Use a process-based pool because several AMT model functions (e.g.
% breebaart2001 via comp_adaptloop) rely on MEX functions, which are not
% supported on thread pools.
% VENV_PYTHON is read by models/takanen2013/amt_extern_rd.m to run the
% verhulst2012 periphery (AMT external Python environment).
setenv('VENV_PYTHON', char(amt_python));
if use_parallel
    pool = gcp('nocreate');
    if isempty(pool) || ~isa(pool, 'parallel.ProcessPool')
        if ~isempty(pool)
            delete(pool);
        end
        parpool('Processes');
    end

    % Propagate the Python interpreter to all workers.
    pool = gcp('nocreate');
    if ~isempty(pool)
        pctRunOnAll setenv('VENV_PYTHON', getenv('VENV_PYTHON'));
    end
end

%% Running the simulations

eval_cfg = struct( ...
    'run_lindemann1986', run_lindemann1986, ...
    'run_breebaart2001', run_breebaart2001, ...
    'run_faller2004', run_faller2004, ...
    'run_may2011', run_may2011, ...
    'run_dietz2011', run_dietz2011, ...
    'run_takanen2013', run_takanen2013, ...
    'run_llado2025', run_llado2025, ...
    'run_extended_re', run_extended_re, ...
    'run_saddler2024', run_saddler2024, ...
    'run_wang2026', run_wang2026, ...
    'run_vecchiotti2019', run_vecchiotti2019, ...
    'use_parallel', use_parallel, ...
    'lvl_dB', 70, ...
    'fLow', 80, ...
    'fHigh', 8000, ...
    'spacingERB', 1, ...
    'frank2013_single_burst', frank2013_single_burst, ...
    'pyFolder', pyFolder, ...
    'venvPython', venvPython, ...
    'wang2026_pyFolder', wang2026_pyFolder, ...
    'wang2026_venvPython', wang2026_venvPython, ...
    'wang2026_model_filename', wang2026_model_filename, ...
    'compute_r2_ci', compute_r2_ci, ...
    'compute_slope_ci', compute_slope_ci, ...
    'fit_ci_opts', fit_ci_opts);

cache_meta = struct();
cache_meta.run_multi_hrtf = run_multi_hrtf;
if run_multi_hrtf
    cache_meta.multi_hrtf_sofa_dir = multi_hrtf_sofa_dir;
    cache_meta.multi_hrtf_sofa_names = hrtf_names;
end

geometry_to_compute = intersect(models_to_compute, geometry_model_ids_local, 'stable');
geometry_from_cache = intersect(models_from_cache, geometry_model_ids_local, 'stable');
hrtf_models_to_compute = intersect(models_to_compute, hrtf_dependent_model_ids, 'stable');
hrtf_models_from_cache = intersect(models_from_cache, hrtf_dependent_model_ids, 'stable');

geometry_preds = struct();
geometry_label = geometry_model_ids('label');
if ~isempty(geometry_from_cache)
    geometry_preds = load_cached_preds_for_hrtf( ...
        model_output_dir, cache_dataset_id, geometry_label, geometry_from_cache);
end
if ~isempty(geometry_to_compute)
    obj_geom = SOFAload(sofa_paths{1});
    geom_eval_cfg = eval_cfg;
    geom_eval_cfg.models_to_compute = geometry_to_compute;
    geometry_new_preds = evaluate_models_for_hrtf( ...
        obj_geom, geometry_label, listexp_data, listexp_data_id, geom_eval_cfg);
    geometry_preds = merge_preds_structs(geometry_preds, geometry_new_preds);
    if save_model_output_data
        save_computed_model_pieces(model_output_dir, cache_dataset_id, geometry_label, ...
            geometry_to_compute, listexp_data, geometry_new_preds, eval_cfg, cache_meta);
    end
end

if run_multi_hrtf
    fprintf('Multi-HRTF mode: evaluating %d SOFA files from %s\n', ...
        numel(sofa_paths), multi_hrtf_sofa_dir);
end

preds_by_hrtf = cell(1, numel(sofa_paths));
for ih = 1:numel(sofa_paths)
    hrtf_name = hrtf_names{ih};
    if run_multi_hrtf
        fprintf('--- HRTF %d/%d: %s ---\n', ih, numel(sofa_paths), hrtf_name);
    end

    preds = struct();
    if ~isempty(fieldnames(geometry_preds))
        preds = merge_preds_structs(preds, geometry_preds);
    end

    if ~isempty(hrtf_models_from_cache)
        cached_preds = load_cached_preds_for_hrtf( ...
            model_output_dir, cache_dataset_id, hrtf_name, hrtf_models_from_cache);
        preds = merge_preds_structs(preds, cached_preds);
    end

    if ~isempty(hrtf_models_to_compute)
        obj = SOFAload(sofa_paths{ih});
        hrtf_eval_cfg = eval_cfg;
        hrtf_eval_cfg.models_to_compute = hrtf_models_to_compute;
        hrtf_eval_cfg.skip_geometry_models = true;
        new_preds = evaluate_models_for_hrtf( ...
            obj, hrtf_name, listexp_data, listexp_data_id, hrtf_eval_cfg);
        preds = merge_preds_structs(preds, new_preds);
        if save_model_output_data
            save_computed_model_pieces(model_output_dir, cache_dataset_id, hrtf_name, ...
                hrtf_models_to_compute, listexp_data, new_preds, eval_cfg, cache_meta);
        end
    end

    preds_by_hrtf{ih} = preds;
end

if run_multi_hrtf
    [preds_mean, preds_sem] = aggregate_hrtf_predictions(preds_by_hrtf);
else
    preds_mean = preds_by_hrtf{1};
    preds_sem = struct();
end

% Optional fold_lr view: responses from native fold loader; preds trial-weighted.
if strcmp(listexp_data_id, 'simon2010')
    [listexp_data, preds_mean, preds_sem] = apply_simon2010_hemisphere_view( ...
        listexp_data, simon2010_plot_hemisphere, preds_mean, preds_sem);
end

[results, workspace_vars] = build_results_from_predictions( ...
    preds_mean, preds_sem, listexp_data, eval_cfg);
assign_struct_to_caller(workspace_vars);

%% Assemble error structs for plotting (fixed model order)
errors_to_plot = assemble_errors_to_plot(results, enabled_model_ids);

%% Plot all error summaries
if ~skip_plot
    single_color_info = build_color_info_for_dataset(listexp_data, listexp_data.listexp_data_id);
    plot_estimatederror_grid(errors_to_plot, listexp_data.listexp_data_id, ...
        single_color_info, plot_equal_xy_limits, figure_save_opts);
end

%% Local functions
function plot_assembled_single_dataset_output(loaded_data, skip_plot, plot_equal_xy_limits, ...
    figure_save_opts, simon2010_hemisphere)
%PLOT_ASSEMBLED_SINGLE_DATASET_OUTPUT Plot from an assembled cache struct.
if nargin < 5 || isempty(simon2010_hemisphere)
    simon2010_hemisphere = 'fold_lr';
end
if ~isfield(loaded_data, 'error_struct_names') || isempty(loaded_data.error_struct_names)
    error('Assembled output has no error_struct_names.');
end

errors_to_plot = cell(1, numel(loaded_data.error_struct_names));
for k = 1:numel(loaded_data.error_struct_names)
    errors_to_plot{k} = loaded_data.(loaded_data.error_struct_names{k});
    est_sem = get_saved_model_sem(loaded_data, errors_to_plot{k}.model_id);
    if ~isempty(est_sem)
        errors_to_plot{k}.est_yerr = est_sem;
    end
end

cached_listexp_data = load_listexp_for_view(loaded_data.listexp_data_id, ...
    simon2010_hemisphere);
cached_color_info = build_color_info_for_dataset( ...
    cached_listexp_data, loaded_data.listexp_data_id);
if ~skip_plot
    plot_estimatederror_grid(errors_to_plot, ...
        loaded_data.listexp_data_id, cached_color_info, plot_equal_xy_limits, ...
        figure_save_opts);
end
end

function model_ids = get_union_model_ids(saved_results)
%GET_UNION_MODEL_IDS Unique model ids across several saved-output structs.
model_ids = {};
for ridx = 1:numel(saved_results)
    S = saved_results{ridx};
    if ~isfield(S, 'error_struct_names')
        continue;
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

function errors_to_plot = assemble_errors_to_plot(results, model_ids)
%ASSEMBLE_ERRORS_TO_PLOT Error structs in model_plot_order for grid figures.
plot_model_ids = reorder_model_ids(model_ids, model_plot_order());
errors_to_plot = {};
for k = 1:numel(plot_model_ids)
    if isfield(results, plot_model_ids{k})
        errors_to_plot{end + 1} = results.(plot_model_ids{k}); %#ok<AGROW>
    end
end
end

function [est_pred, est_resp] = get_saved_prediction_and_response_for_model( ...
    S, model_id, simon2010_hemisphere)
%GET_SAVED_PREDICTION_AND_RESPONSE_FOR_MODEL Predictions and responses for a model.
if nargin < 3 || isempty(simon2010_hemisphere)
    simon2010_hemisphere = 'fold_lr';
end
est_pred = get_saved_model_predictions(S, model_id);
if ~isfield(S, 'listexp_data_id')
    error('Missing listexp_data_id in saved output.');
end

listexp_data_local = load_listexp_for_view(S.listexp_data_id, simon2010_hemisphere);
est_resp = listexp_data_local.avgResponseVector(:);

if numel(est_pred) ~= numel(est_resp)
    error('Length mismatch for model %s and dataset %s: pred=%d, resp=%d', ...
        model_id, S.listexp_data_id, numel(est_pred), numel(est_resp));
end
end

function listexp_data = load_listexp_for_view(dataset_id, simon2010_hemisphere)
%LOAD_LISTEXP_FOR_VIEW Load perceptual data for the current fit/plot view.
if startsWith(dataset_id, 'simon2010')
    load_opts = struct('simon2010_hemisphere', simon2010_hemisphere);
    listexp_data = load_listexp_data('simon2010', 0, load_opts);
    listexp_data.listexp_data_id = 'simon2010';
else
    listexp_data = load_listexp_data(dataset_id, 0);
    listexp_data.listexp_data_id = dataset_id;
end
end

function clear_combined_recompute_overrides()
%CLEAR_COMBINED_RECOMPUTE_OVERRIDES Reset environment overrides after a subrun.
setenv('MC_RUN_MODE_OVERRIDE', '');
setenv('MC_LISTEXP_DATASET_OVERRIDE', '');
setenv('MC_SIMON2010_HEMISPHERE_OVERRIDE', '');
setenv('MC_LOAD_EXISTING_OVERRIDE', '');
setenv('MC_SAVE_OUTPUT_OVERRIDE', '');
setenv('MC_MODEL_OUTPUT_DIR_OVERRIDE', '');
setenv('MC_SKIP_PLOT_OVERRIDE', '');
setenv('MC_RUN_MULTI_HRTF_OVERRIDE', '');
setenv('MC_MULTI_HRTF_SOFA_DIR_OVERRIDE', '');
setenv('MC_RECOMPUTE_MODELS_OVERRIDE', '');
end

function run_selective_recompute_for_datasets( ...
    script_path, dataset_ids, model_output_dir, recompute_model_ids, ...
    run_multi_hrtf, multi_hrtf_sofa_dir, simon2010_hemisphere)
%RUN_SELECTIVE_RECOMPUTE_FOR_DATASETS Recompute listed models for each dataset.
if nargin < 7 || isempty(simon2010_hemisphere)
    simon2010_hemisphere = 'fold_lr';
end
fprintf('Selective recompute for models: %s\n', strjoin(recompute_model_ids, ', '));
for dsIdx = 1:numel(dataset_ids)
    dataset_id = dataset_ids{dsIdx};
    fprintf('Selective recompute for dataset: %s\n', dataset_id);
    setenv('MC_RUN_MODE_OVERRIDE', 'single');
    setenv('MC_LISTEXP_DATASET_OVERRIDE', dataset_id);
    setenv('MC_SIMON2010_HEMISPHERE_OVERRIDE', simon2010_hemisphere);
    setenv('MC_LOAD_EXISTING_OVERRIDE', 'true');
    setenv('MC_SAVE_OUTPUT_OVERRIDE', 'true');
    setenv('MC_MODEL_OUTPUT_DIR_OVERRIDE', model_output_dir);
    setenv('MC_SKIP_PLOT_OVERRIDE', 'true');
    setenv('MC_RECOMPUTE_MODELS_OVERRIDE', strjoin(recompute_model_ids, ','));
    if run_multi_hrtf
        setenv('MC_RUN_MULTI_HRTF_OVERRIDE', 'true');
        setenv('MC_MULTI_HRTF_SOFA_DIR_OVERRIDE', multi_hrtf_sofa_dir);
    else
        setenv('MC_RUN_MULTI_HRTF_OVERRIDE', 'false');
        setenv('MC_MULTI_HRTF_SOFA_DIR_OVERRIDE', '');
    end
    cleanup_env = onCleanup(@() clear_combined_recompute_overrides());
    run(script_path);
    clear cleanup_env;
end
end

function cleanup_combined_recompute_temp(temp_dir)
%CLEANUP_COMBINED_RECOMPUTE_TEMP Remove a temporary recompute output directory.
if ~isempty(temp_dir) && isfolder(temp_dir)
    rmdir(temp_dir, 's');
end
end

function enabled_model_ids = get_enabled_model_ids_from_flags( ...
    run_lindemann1986, run_breebaart2001, run_faller2004, run_may2011, ...
    run_dietz2011, run_takanen2013, run_llado2025, run_extended_re, ...
    run_saddler2024, run_wang2026, run_vecchiotti2019)
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
