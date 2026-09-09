function ordered = reorder_model_ids(model_ids, preferred_order)
%REORDER_MODEL_IDS Sort model ids by preferred_order; unknown ids keep input order at end.
model_ids = cellstr(model_ids);
preferred_order = cellstr(preferred_order);

ordered = {};
for k = 1:numel(preferred_order)
    if any(strcmp(model_ids, preferred_order{k}))
        ordered{end + 1} = preferred_order{k}; %#ok<AGROW>
    end
end

extra = setdiff(model_ids, ordered, 'stable');
ordered = [ordered, extra];
end
