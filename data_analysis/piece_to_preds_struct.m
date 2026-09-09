function preds = piece_to_preds_struct(piece, model_id)
%PIECE_TO_PREDS_STRUCT Extract prediction fields from one cache piece.
preds = struct();
model_id = canonical_model_id(model_id);
field_names = model_output_piece_field_names(model_id);
legacy_aliases = legacy_piece_field_aliases(model_id);
for iField = 1:numel(field_names)
    fname = field_names{iField};
    if isfield(piece, fname)
        preds.(fname) = piece.(fname);
    elseif isfield(legacy_aliases, fname) && isfield(piece, legacy_aliases.(fname))
        preds.(fname) = piece.(legacy_aliases.(fname));
    end
end
end

function aliases = legacy_piece_field_aliases(model_id)
aliases = struct();
switch model_id
    case 'llado2025'
        aliases.est_angle_llado2025 = 'est_angle_desena2020';
        aliases.error_llado2025 = 'error_desena2020';
        aliases.time_llado2025_s = 'time_desena2020_s';
    otherwise
        % No legacy field names for the remaining models.
end
end
