function model_ids = list_cached_models(model_output_dir, dataset_id, sofa_name)
%LIST_CACHED_MODELS Model ids with an existing per-model cache piece.
safe_dataset = sanitize_model_output_token(dataset_id);
safe_sofa = sanitize_model_output_token(sofa_name);
pattern = fullfile(model_output_dir, ...
    sprintf('MC_MODEL_OUTPUT_%s_%s_*.mat', safe_dataset, safe_sofa));
files = dir(pattern);
model_ids = {};
for iFile = 1:numel(files)
    [~, basename, ~] = fileparts(files(iFile).name);
    model_id = parse_model_id_from_cache_basename(basename, dataset_id, sofa_name);
    if ~isempty(model_id)
        model_ids{end + 1} = model_id; %#ok<AGROW>
    end
end
model_ids = unique(model_ids, 'stable');
end

function model_id = parse_model_id_from_cache_basename(basename, dataset_id, sofa_name)
model_id = '';
safe_dataset = sanitize_model_output_token(dataset_id);
safe_sofa = sanitize_model_output_token(sofa_name);
prefix = sprintf('MC_MODEL_OUTPUT_%s_%s_', safe_dataset, safe_sofa);
if ~startsWith(basename, prefix)
    return;
end
remainder = char(extractAfter(basename, prefix));
if isempty(remainder)
    return;
end
known_ids = all_model_output_model_ids();
for iId = 1:numel(known_ids)
    if strcmp(remainder, known_ids{iId})
        model_id = known_ids{iId};
        return;
    end
end
legacy_cache_specs = {
    'desena2020', 'llado2025'};
for ridx = 1:size(legacy_cache_specs, 1)
    if strcmp(remainder, legacy_cache_specs{ridx, 1})
        model_id = legacy_cache_specs{ridx, 2};
        return;
    end
end
end
