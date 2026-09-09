function S = assemble_model_output(model_output_dir, dataset_id, aggregate_sofa_name, varargin)
%ASSEMBLE_MODEL_OUTPUT Merge per-model cache pieces into one virtual struct.
%
%   S = ASSEMBLE_MODEL_OUTPUT(dir, dataset_id, aggregate_sofa_name, ...)
%
% Name-value options:
%   'model_ids'            Cell of model ids to include (default: all cached).
%   'multi_hrtf_sofa_dir'  Folder of individual SOFA files for multi-HRTF runs.
%   'compute_r2_ci'        Recompute bootstrap CIs when aggregating (default false).
%   'compute_slope_ci'     Recompute slope CIs when aggregating (default false).
%   'fit_ci_opts'          Bootstrap options when CIs are recomputed.
%   'simon2010_hemisphere' For simon2010: 'fold_lr' (default) or 'separate'
%                          plot/fit view. Caches are always directed/separate.

p = inputParser;
addParameter(p, 'model_ids', {}, @iscell);
addParameter(p, 'multi_hrtf_sofa_dir', '', @(x) ischar(x) || isstring(x));
addParameter(p, 'compute_r2_ci', false, @islogical);
addParameter(p, 'compute_slope_ci', false, @islogical);
addParameter(p, 'fit_ci_opts', struct(), @isstruct);
addParameter(p, 'simon2010_hemisphere', 'fold_lr', @(x) ischar(x) || isstring(x));
parse(p, varargin{:});
opts = p.Results;

% Legacy alias: simon2010_separate caches collapsed into simon2010.
cache_dataset_id = dataset_id;
if strcmp(dataset_id, 'simon2010_separate')
    cache_dataset_id = 'simon2010';
end

if isempty(opts.model_ids)
    model_ids = discover_cached_model_ids(model_output_dir, cache_dataset_id);
else
    model_ids = opts.model_ids;
end

if isempty(model_ids)
    error('assemble_model_output:NoData', ...
        'No model output cache found for dataset %s.', cache_dataset_id);
end

is_multi = startsWith(aggregate_sofa_name, 'MULTI_');
if is_multi && ~isempty(opts.multi_hrtf_sofa_dir)
    [~, hrtf_names] = list_sofa_files_in_folder(opts.multi_hrtf_sofa_dir);
elseif is_multi
    hrtf_names = discover_hrtf_names_from_cache(model_output_dir, cache_dataset_id);
else
    hrtf_names = {aggregate_sofa_name};
end

if isempty(hrtf_names)
    error('assemble_model_output:NoHrtfs', ...
        'Could not resolve HRTF list for dataset %s.', cache_dataset_id);
end

geometry_preds = struct();
geometry_label = geometry_model_ids('label');
for iModel = 1:numel(model_ids)
    model_id = model_ids{iModel};
    if ~geometry_model_ids('is', model_id)
        continue;
    end
    piece_preds = load_model_preds_if_cached( ...
        model_output_dir, cache_dataset_id, geometry_label, model_id);
    if isempty(fieldnames(piece_preds))
        continue;
    end
    geometry_preds = merge_preds_structs(geometry_preds, piece_preds);
end

preds_by_hrtf = cell(1, numel(hrtf_names));
meta = struct();
for ih = 1:numel(hrtf_names)
    hrtf_name = hrtf_names{ih};
    preds = struct();
    if ~isempty(fieldnames(geometry_preds))
        preds = merge_preds_structs(preds, geometry_preds);
    end
    for iModel = 1:numel(model_ids)
        model_id = model_ids{iModel};
        if geometry_model_ids('is', model_id)
            continue;
        end
        piece_preds = load_model_preds_if_cached( ...
            model_output_dir, cache_dataset_id, hrtf_name, model_id);
        if isempty(fieldnames(piece_preds))
            continue;
        end
        preds = merge_preds_structs(preds, piece_preds);
        if isempty(fieldnames(meta))
            cache_path = resolve_model_output_cache_path( ...
                model_output_dir, cache_dataset_id, hrtf_name, model_id);
            piece = load_model_output_piece(cache_path);
            meta = copy_meta_fields(piece);
        end
    end
    preds_by_hrtf{ih} = preds;
end

has_piece_preds = any(cellfun(@(p) ~isempty(fieldnames(p)), preds_by_hrtf));
if ~has_piece_preds
    error('assemble_model_output:NoData', ...
        'No per-model cache pieces found for dataset %s.', cache_dataset_id);
end

if numel(hrtf_names) > 1
    [preds_mean, preds_sem] = aggregate_hrtf_predictions(preds_by_hrtf);
else
    preds_mean = preds_by_hrtf{1};
    preds_sem = struct();
end

base_dataset_id = cache_dataset_id;
listexp_data = load_listexp_data(base_dataset_id, 0, ...
    struct('simon2010_hemisphere', 'separate'));
listexp_data.listexp_data_id = base_dataset_id;

if strcmp(base_dataset_id, 'simon2010')
    [listexp_data, preds_mean, preds_sem] = apply_simon2010_hemisphere_view( ...
        listexp_data, opts.simon2010_hemisphere, preds_mean, preds_sem);
end

eval_cfg = build_assembly_eval_cfg(model_ids, opts);
[~, workspace_vars] = build_results_from_predictions( ...
    preds_mean, preds_sem, listexp_data, eval_cfg);

S = workspace_vars;
S.listexp_data_id = base_dataset_id;
S.sofa_name = aggregate_sofa_name;
S.run_multi_hrtf = is_multi;
if strcmp(base_dataset_id, 'simon2010')
    S.simon2010_hemisphere = char(string(opts.simon2010_hemisphere));
end
if isfield(meta, 'multi_hrtf_sofa_dir')
    S.multi_hrtf_sofa_dir = meta.multi_hrtf_sofa_dir;
end
if is_multi
    S.multi_hrtf_sofa_names = hrtf_names;
end

plot_model_ids = reorder_model_ids(model_ids, model_plot_order());
error_struct_names = {};
for iModel = 1:numel(plot_model_ids)
    err_name = ['error_' plot_model_ids{iModel}];
    if isfield(S, err_name)
        error_struct_names{end + 1} = err_name; %#ok<AGROW>
    end
end
S.error_struct_names = error_struct_names;
fprintf('Assembled model output for %s (%d models, %d HRTFs).\n', ...
    cache_dataset_id, numel(error_struct_names), numel(hrtf_names));
end

function preds = load_model_preds_if_cached(model_output_dir, dataset_id, sofa_name, model_id)
preds = struct();
cache_path = resolve_model_output_cache_path(model_output_dir, dataset_id, sofa_name, model_id);
if ~isfile(cache_path)
    return;
end
piece = load_model_output_piece(cache_path);
preds = piece_to_preds_struct(piece, model_id);
end

function meta = copy_meta_fields(piece)
meta = struct();
meta_fields = {'run_multi_hrtf', 'multi_hrtf_sofa_dir', 'multi_hrtf_sofa_names'};
for iField = 1:numel(meta_fields)
    if isfield(piece, meta_fields{iField})
        meta.(meta_fields{iField}) = piece.(meta_fields{iField});
    end
end
end

function model_ids = discover_cached_model_ids(model_output_dir, dataset_id)
model_ids = {};
known_ids = all_model_output_model_ids();
geometry_cached = list_cached_models(model_output_dir, dataset_id, geometry_model_ids('label'));
cached_hrtfs = discover_hrtf_names_from_cache(model_output_dir, dataset_id);
for iId = 1:numel(known_ids)
    mid = known_ids{iId};
    if geometry_model_ids('is', mid)
        if ismember(mid, geometry_cached)
            model_ids{end + 1} = mid; %#ok<AGROW>
        end
        continue;
    end
    if is_model_fully_cached_local(model_output_dir, dataset_id, cached_hrtfs, mid)
        model_ids{end + 1} = mid; %#ok<AGROW>
    end
end
model_ids = unique(model_ids, 'stable');
end

function eval_cfg = build_assembly_eval_cfg(model_ids, opts)
eval_cfg = struct( ...
    'run_lindemann1986', false, ...
    'run_breebaart2001', false, ...
    'run_faller2004', false, ...
    'run_may2011', false, ...
    'run_dietz2011', false, ...
    'run_takanen2013', false, ...
    'run_llado2025', false, ...
    'run_extended_re', false, ...
    'run_saddler2024', false, ...
    'run_wang2026', false, ...
    'run_vecchiotti2019', false, ...
    'compute_r2_ci', opts.compute_r2_ci, ...
    'compute_slope_ci', opts.compute_slope_ci, ...
    'fit_ci_opts', opts.fit_ci_opts);
eval_cfg = restrict_eval_cfg_to_models(eval_cfg, model_ids);
end

function tf = is_model_fully_cached_local(model_output_dir, dataset_id, hrtf_names, model_id)
model_id = char(model_id);

if geometry_model_ids('is', model_id)
    cache_sofa = geometry_model_ids('label');
    tf = is_model_output_piece_valid_local(model_output_dir, dataset_id, cache_sofa, model_id);
    return;
end

if isempty(hrtf_names)
    tf = false;
    return;
end

tf = true;
for iHrtf = 1:numel(hrtf_names)
    if ~is_model_output_piece_valid_local(model_output_dir, dataset_id, hrtf_names{iHrtf}, model_id)
        tf = false;
        return;
    end
end
end

function tf = is_model_output_piece_valid_local(model_output_dir, dataset_id, sofa_name, model_id)
model_id = canonical_model_id(model_id);
cache_path = resolve_model_output_cache_path(model_output_dir, dataset_id, sofa_name, model_id);
if ~isfile(cache_path)
    tf = false;
    return;
end

piece = load_model_output_piece(cache_path);
preds = piece_to_preds_struct(piece, model_id);
tf = ~isempty(fieldnames(preds));
if ~tf
    return;
end

if strcmp(model_id, 'saddler2024')
    pred_field = 'est_angle_expected_saddler2024';
else
    pred_field = ['est_angle_' model_id];
end
if isfield(preds, pred_field)
    tf = ~isempty(preds.(pred_field));
else
    tf = false;
end
if tf && strcmp(dataset_id, 'simon2010')
    d = load_listexp_data('simon2010', 0, struct('simon2010_hemisphere', 'separate'));
    tf = numel(preds.(pred_field)) == numel(d.avgResponseVector);
end
end
