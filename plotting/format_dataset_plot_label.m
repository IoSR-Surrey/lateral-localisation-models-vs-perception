function label = format_dataset_plot_label(dataset_id)
%FORMAT_DATASET_PLOT_LABEL Display label for a dataset id in figures.
%
%   label = FORMAT_DATASET_PLOT_LABEL(dataset_id) returns the string shown
%   in plot legends and R^2 panel titles. Listening-experiment ids get a
%   "data_" prefix (e.g. simon2010 -> data_simon2010). Combined / other
%   tokens are left unchanged.

dataset_id = char(string(dataset_id));
if startsWith(dataset_id, 'data_')
    label = dataset_id;
    return
end

known_ids = { ...
    'simon2010', 'desena2013', 'frank2013', 'ramirez2024', 'llado2026'};
if ismember(dataset_id, known_ids)
    label = ['data_' dataset_id];
else
    label = dataset_id;
end
end
