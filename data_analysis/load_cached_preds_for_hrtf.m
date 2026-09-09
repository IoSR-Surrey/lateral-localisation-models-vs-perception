function preds = load_cached_preds_for_hrtf(model_output_dir, dataset_id, hrtf_name, model_ids)
%LOAD_CACHED_PREDS_FOR_HRTF Merge cached per-model predictions for one HRTF.
preds = struct();
geometry_label = geometry_model_ids('label');
for iModel = 1:numel(model_ids)
    model_id = model_ids{iModel};
    if geometry_model_ids('is', model_id)
        cache_sofa = geometry_label;
    else
        cache_sofa = hrtf_name;
    end
    cache_path = resolve_model_output_cache_path(model_output_dir, dataset_id, cache_sofa, model_id);
    if ~isfile(cache_path)
        error('load_cached_preds_for_hrtf:MissingPiece', ...
            'Missing cache for dataset %s, HRTF %s, model %s.', ...
            dataset_id, cache_sofa, model_id);
    end
    piece = load_model_output_piece(cache_path);
    piece_preds = piece_to_preds_struct(piece, model_id);
    if isempty(fieldnames(piece_preds))
        error('load_cached_preds_for_hrtf:EmptyPiece', ...
            'Cache piece has no predictions for dataset %s, HRTF %s, model %s.', ...
            dataset_id, cache_sofa, model_id);
    end
    preds = merge_preds_structs(preds, piece_preds);
end
end
