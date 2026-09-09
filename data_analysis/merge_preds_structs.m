function preds = merge_preds_structs(preds_a, preds_b)
%MERGE_PREDS_STRUCTS Merge two prediction structs field-wise.
preds = preds_a;
if isempty(fieldnames(preds_b))
    return;
end
b_fields = fieldnames(preds_b);
for iField = 1:numel(b_fields)
    preds.(b_fields{iField}) = preds_b.(b_fields{iField});
end
end
