function sofa_names = discover_aggregate_sofa_names(model_output_dir, dataset_id)
%DISCOVER_AGGREGATE_SOFA_NAMES Aggregate HRTF labels available for a dataset.
sofa_names = {};
individual_hrtfs = discover_hrtf_names_from_cache(model_output_dir, dataset_id);
if isempty(individual_hrtfs)
    return;
end
if numel(individual_hrtfs) == 1
    sofa_names = individual_hrtfs;
    return;
end

multi_dir = '';
for iHrtf = 1:numel(individual_hrtfs)
    cached_models = list_cached_models(model_output_dir, dataset_id, individual_hrtfs{iHrtf});
    if isempty(cached_models)
        continue;
    end
    piece_path = model_output_cache_path( ...
        model_output_dir, dataset_id, individual_hrtfs{iHrtf}, cached_models{1});
    piece = load_model_output_piece(piece_path);
    if isfield(piece, 'multi_hrtf_sofa_dir') && ~isempty(piece.multi_hrtf_sofa_dir)
        multi_dir = piece.multi_hrtf_sofa_dir;
        break;
    end
end
if ~isempty(multi_dir)
    sofa_names = {derive_multi_hrtf_cache_label(multi_dir)};
else
    sofa_names = individual_hrtfs;
end
sofa_names = unique(sofa_names, 'stable');
end
