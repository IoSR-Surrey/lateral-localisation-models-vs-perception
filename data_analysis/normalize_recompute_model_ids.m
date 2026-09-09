function model_ids = normalize_recompute_model_ids(model_ids)
%NORMALIZE_RECOMPUTE_MODEL_IDS Canonicalize recompute_model_ids and warn on mistakes.
%
%   Maps legacy model ids (e.g. desena2020 -> llado2025) and warns when a
%   dataset id (e.g. llado2026) is passed instead of a model id.

known_dataset_ids = {'desena2013', 'simon2010', 'llado2026', 'ramirez2024', ...
    'frank2013'};

model_ids = cellstr(model_ids);
out = {};
for iId = 1:numel(model_ids)
    mid = char(strtrim(string(model_ids{iId})));
    if isempty(mid)
        continue;
    end
    if ismember(mid, known_dataset_ids)
        warning('normalize_recompute_model_ids:DatasetId', ...
            ['"%s" is a dataset id, not a model id. ', ...
            'Set listexp_data_id (or combined_dataset_ids) for datasets, ', ...
            'and recompute_model_ids for models (e.g. ''llado2025'').'], mid);
        continue;
    end
    out{end + 1} = canonical_model_id(mid); %#ok<AGROW>
end
model_ids = unique(out, 'stable');
end
