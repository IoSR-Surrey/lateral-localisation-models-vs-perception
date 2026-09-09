function [models_to_compute, models_from_cache, all_fully_cached] = resolve_models_to_compute( ...
    model_output_dir, dataset_id, hrtf_names, enabled_model_ids, ...
    load_existing, recompute_model_ids)
%RESOLVE_MODELS_TO_COMPUTE Split enabled models into compute vs cache loads.
%
%   hrtf_names is a cell of individual SOFA basenames used for cache lookup.
%   Geometry-only models use the GEOMETRY sentinel label instead.
%
%   all_fully_cached is true when every enabled model has complete cache pieces.

models_to_compute = {};
models_from_cache = {};
all_fully_cached = false;
recompute_model_ids = cellstr(recompute_model_ids);
recompute_model_ids = normalize_recompute_model_ids(recompute_model_ids);

if isempty(enabled_model_ids)
    return;
end

all_fully_cached = true;
for iModel = 1:numel(enabled_model_ids)
    model_id = enabled_model_ids{iModel};
    force_recompute = ismember(model_id, recompute_model_ids);
    if ~load_existing || force_recompute
        models_to_compute{end + 1} = model_id; %#ok<AGROW>
        all_fully_cached = false;
        continue;
    end

    if is_model_fully_cached(model_output_dir, dataset_id, hrtf_names, model_id)
        models_from_cache{end + 1} = model_id; %#ok<AGROW>
    else
        models_to_compute{end + 1} = model_id; %#ok<AGROW>
        all_fully_cached = false;
    end
end
end

function tf = is_model_fully_cached(model_output_dir, dataset_id, hrtf_names, model_id)
model_id = char(model_id);

if geometry_model_ids('is', model_id)
    cache_sofa = geometry_model_ids('label');
    tf = is_model_output_piece_valid(model_output_dir, dataset_id, cache_sofa, model_id);
    return;
end

if isempty(hrtf_names)
    tf = false;
    return;
end

tf = true;
for iHrtf = 1:numel(hrtf_names)
    if ~is_model_output_piece_valid(model_output_dir, dataset_id, hrtf_names{iHrtf}, model_id)
        tf = false;
        return;
    end
end
end

function tf = is_model_output_piece_valid(model_output_dir, dataset_id, sofa_name, model_id)
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

pred_field = primary_prediction_field(model_id);
if isfield(preds, pred_field)
    tf = ~isempty(preds.(pred_field));
else
    tf = false;
end
% simon2010 caches must be directed (separate) length; reject old fold-length files.
if tf && strcmp(dataset_id, 'simon2010')
    n_expected = simon2010_separate_n_conditions();
    tf = numel(preds.(pred_field)) == n_expected;
end
end

function n = simon2010_separate_n_conditions()
persistent n_sep;
if isempty(n_sep)
    d = load_listexp_data('simon2010', 0, struct('simon2010_hemisphere', 'separate'));
    n_sep = numel(d.avgResponseVector);
end
n = n_sep;
end

function pred_field = primary_prediction_field(model_id)
model_id = canonical_model_id(model_id);
if strcmp(model_id, 'saddler2024')
    pred_field = 'est_angle_expected_saddler2024';
else
    pred_field = ['est_angle_' model_id];
end
end
