function cache_path = resolve_model_output_cache_path(model_output_dir, dataset_id, sofa_name, model_id)
%RESOLVE_MODEL_OUTPUT_CACHE_PATH Cache path with legacy filename fallback.
%
%   Tries the canonical model id first (e.g. llado2025), then legacy cache
%   filenames still on disk (e.g. desena2020).
%   For simon2010, also falls back to former simon2010_separate cache files
%   (directed L+R conditions are now the single simon2010 cache).

canonical_id = canonical_model_id(model_id);
cache_path = model_output_cache_path(model_output_dir, dataset_id, sofa_name, canonical_id);
if isfile(cache_path)
    return;
end

legacy_ids = legacy_cache_model_ids(canonical_id);
for iLegacy = 1:numel(legacy_ids)
    legacy_path = model_output_cache_path( ...
        model_output_dir, dataset_id, sofa_name, legacy_ids{iLegacy});
    if isfile(legacy_path)
        cache_path = legacy_path;
        return;
    end
end

% Directed simon2010 conditions were previously cached under simon2010_separate.
if strcmp(dataset_id, 'simon2010')
    alt_path = model_output_cache_path( ...
        model_output_dir, 'simon2010_separate', sofa_name, canonical_id);
    if isfile(alt_path)
        cache_path = alt_path;
        return;
    end
    for iLegacy = 1:numel(legacy_ids)
        alt_path = model_output_cache_path( ...
            model_output_dir, 'simon2010_separate', sofa_name, legacy_ids{iLegacy});
        if isfile(alt_path)
            cache_path = alt_path;
            return;
        end
    end
end
end

function legacy_ids = legacy_cache_model_ids(canonical_id)
switch canonical_id
    case 'llado2025'
        legacy_ids = {'desena2020'};
    otherwise
        legacy_ids = {};
end
end
