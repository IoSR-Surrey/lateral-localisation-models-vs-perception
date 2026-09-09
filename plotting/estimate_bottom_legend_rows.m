function n_rows = estimate_bottom_legend_rows(color_info)
%ESTIMATE_BOTTOM_LEGEND_ROWS Bottom margin rows for grid figure legends.

n_rows = 0;
if isempty(color_info) || ~isfield(color_info, 'kind')
    return
end

kind = lower(string(color_info.kind));
if kind == "continuous"
    n_rows = n_rows + 1;
elseif kind == "discrete"
    n_rows = n_rows + 1;
end

if isfield(color_info, 'shape_values') && ~isempty(color_info.shape_values)
    n_rows = n_rows + 1;
end
end
