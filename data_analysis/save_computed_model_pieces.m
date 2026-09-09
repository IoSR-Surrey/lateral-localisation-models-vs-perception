function save_computed_model_pieces(model_output_dir, dataset_id, sofa_name, ...
    model_ids, listexp_data, preds, eval_cfg, meta)
%SAVE_COMPUTED_MODEL_PIECES Persist per-model cache pieces after evaluation.
if isempty(model_ids)
    return;
end
for iModel = 1:numel(model_ids)
    model_id = model_ids{iModel};
    pred_field = primary_prediction_field(model_id);
    if ~isfield(preds, pred_field) || isempty(preds.(pred_field))
        warning('save_computed_model_pieces:SkipEmpty', ...
            'Skipping save for model %s (no predictions).', model_id);
        continue;
    end
    piece = build_model_output_piece(model_id, listexp_data, dataset_id, ...
        sofa_name, preds, eval_cfg, meta);
    cache_path = model_output_cache_path(model_output_dir, dataset_id, sofa_name, model_id);
    save_model_output_piece(cache_path, piece);
    fprintf('Saved model output piece: %s\n', cache_path);
end
end

function piece = build_model_output_piece(model_id, listexp_data, listexp_data_id, ...
    sofa_name, preds, eval_cfg, meta)
model_id = char(model_id);
mini_cfg = restrict_eval_cfg_to_models(eval_cfg, {model_id});
[~, workspace_vars] = build_results_from_predictions( ...
    preds, struct(), listexp_data, mini_cfg);

piece = struct();
piece.listexp_data_id = listexp_data_id;
piece.sofa_name = sofa_name;
piece.model_id = model_id;

meta_fields = {'run_multi_hrtf', 'multi_hrtf_sofa_dir', 'multi_hrtf_sofa_names'};
for iField = 1:numel(meta_fields)
    if isfield(meta, meta_fields{iField})
        piece.(meta_fields{iField}) = meta.(meta_fields{iField});
    end
end

field_names = model_output_piece_field_names(model_id);
for iField = 1:numel(field_names)
    fname = field_names{iField};
    if isfield(workspace_vars, fname)
        piece.(fname) = workspace_vars.(fname);
    elseif isfield(preds, fname)
        piece.(fname) = preds.(fname);
    end
end
end

function pred_field = primary_prediction_field(model_id)
if strcmp(model_id, 'saddler2024')
    pred_field = 'est_angle_expected_saddler2024';
else
    pred_field = ['est_angle_' model_id];
end
end
