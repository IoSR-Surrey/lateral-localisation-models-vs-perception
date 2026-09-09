function assign_struct_to_caller(S)
%ASSIGN_STRUCT_TO_CALLER Copy struct fields into the caller workspace.
%   Used by scripts to expose dynamically named prediction variables after
%   build_results_from_predictions without eval in the script body.
names = fieldnames(S);
for k = 1:numel(names)
    assignin('caller', names{k}, S.(names{k}));
end
end
