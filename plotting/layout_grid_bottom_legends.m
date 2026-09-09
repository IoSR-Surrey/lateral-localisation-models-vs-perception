function layout_grid_bottom_legends(tl, tile_axes, color_info, pub_fs)
%LAYOUT_GRID_BOTTOM_LEGENDS Place centred bottom colorbar/legend groups.
%
%   Renders each encoding (discrete colour, continuous colour bar, marker
%   shape) as a separate horizontal row below the shared x-axis label.
%   Each row uses a dedicated invisible axes below the tiled layout so
%   multiple legends can coexist without overwriting one another.

if nargin < 4 || isempty(pub_fs)
    pub_fs = grid_publication_font_sizes();
end

proto_ax = tile_axes(1);
ud = proto_ax.UserData;
if ~isstruct(ud)
    ud = struct();
end

groups = struct('handles', {}, 'labels', {}, 'title', {});
use_colorbar = false;
colorbar_label = '';

if ~isempty(color_info) && isfield(color_info, 'kind')
    kind = lower(string(color_info.kind));
    if kind == "discrete" ...
            && isfield(ud, 'color_proto_handles') ...
            && ~isempty(ud.color_proto_handles)
        for k = 1:numel(ud.color_proto_handles)
            set(ud.color_proto_handles(k), 'HandleVisibility', 'on');
        end
        groups(end + 1) = struct( ... %#ok<AGROW>
            'handles', {ud.color_proto_handles(:)'}, ...
            'labels', {ud.color_proto_labels(:)'}, ...
            'title', {pick_color_group_title(color_info)});
    elseif kind == "continuous"
        use_colorbar = true;
        if isfield(color_info, 'label') && ~isempty(color_info.label)
            colorbar_label = char(color_info.label);
        end
    end

    if isfield(color_info, 'shape_values') && ~isempty(color_info.shape_values) ...
            && isfield(ud, 'shape_proto_handles') ...
            && ~isempty(ud.shape_proto_handles)
        for k = 1:numel(ud.shape_proto_handles)
            set(ud.shape_proto_handles(k), 'HandleVisibility', 'on');
        end
        shape_title = '';
        if isfield(color_info, 'shape_label') && ~isempty(color_info.shape_label)
            shape_title = char(color_info.shape_label);
        end
        groups(end + 1) = struct( ... %#ok<AGROW>
            'handles', {ud.shape_proto_handles(:)'}, ...
            'labels', {ud.shape_proto_labels(:)'}, ...
            'title', {shape_title});
    end
end

n_group_rows = numel(groups);
if ~use_colorbar && n_group_rows == 0
    return
end

row_heights = zeros(1, n_group_rows);
max_cols = 6;
for ig = 1:n_group_rows
    n_items = numel(groups(ig).handles);
    n_wrap_rows = ceil(n_items / max_cols);
    row_heights(ig) = 0.028 + 0.024 * n_wrap_rows;
end

colorbar_row_h = 0;
if use_colorbar
    colorbar_row_h = 0.036;
end

group_gap = 0.005;
legend_stack_h = colorbar_row_h;
if use_colorbar && n_group_rows > 0
    legend_stack_h = legend_stack_h + group_gap;
end
for ig = 1:n_group_rows
    legend_stack_h = legend_stack_h + row_heights(ig);
    if ig < n_group_rows
        legend_stack_h = legend_stack_h + group_gap;
    end
end

xlabel_gap = 0.014;
bottom_frac = xlabel_gap + legend_stack_h + 0.003;
bottom_frac = min(max(bottom_frac, 0.055), 0.20);

tl.Units = 'normalized';
op = tl.OuterPosition;
tl.OuterPosition = [op(1), op(2) + bottom_frac, op(3), op(4) - bottom_frac];

cursor_y = op(2) + bottom_frac - legend_stack_h - 0.003;
center_x = op(1) + op(3) / 2;
fig = ancestor(tl, 'figure');

if use_colorbar
    cb = colorbar(proto_ax);
    if isprop(cb, 'Orientation')
        cb.Orientation = 'horizontal';
    end
    cb.Units = 'normalized';
    cb_w = min(0.62, max(0.36, 0.12 + 0.04 * numel(tile_axes)));
    cb.Position = [center_x - cb_w / 2, cursor_y, cb_w, colorbar_row_h * 0.72];
    cb.FontSize = pub_fs.legend;
    if ~isempty(colorbar_label)
        cb.Label.String = colorbar_label;
        cb.Label.FontSize = pub_fs.legend_title;
    end
    cursor_y = cursor_y + colorbar_row_h + 0.008;
end

for ig = 1:n_group_rows
    n_items = numel(groups(ig).handles);
    n_cols = min(n_items, max_cols);
    row_h = row_heights(ig);
    est_w = estimate_legend_row_width(op(3), n_items, n_cols);

    leg_ax = axes(fig, ...
        'Units', 'normalized', ...
        'Position', [center_x - est_w / 2, cursor_y, est_w, row_h], ...
        'Visible', 'off', ...
        'HitTest', 'off', ...
        'XTick', [], 'YTick', [], ...
        'XLim', [0 1], 'YLim', [0 1], ...
        'Color', 'none');

    leg_handles = gobjects(n_items, 1);
    for k = 1:n_items
        leg_handles(k) = copyobj(groups(ig).handles(k), leg_ax);
    end

    lg = legend(leg_ax, leg_handles, groups(ig).labels, ...
        'Orientation', 'horizontal', ...
        'NumColumns', n_cols, ...
        'Interpreter', 'none', 'Box', 'off', ...
        'Location', 'south');
    lg.FontSize = pub_fs.legend;
    if isprop(lg, 'HorizontalAlignment')
        lg.HorizontalAlignment = 'center';
    end
    group_title = group_row_title(groups(ig));
    if strlength(string(group_title)) > 0
        title(lg, group_title, 'FontSize', pub_fs.legend_title, ...
            'Interpreter', 'none');
    end
    tighten_legend_row(fig, leg_ax, lg, center_x);

    cursor_y = cursor_y + row_h + 0.008;
end
end

function tighten_legend_row(fig, leg_ax, lg, center_x)
%TIGHTEN_LEGEND_ROW Centre a bottom legend row on its rendered width.

drawnow limitrate;
fig.Units = 'pixels';
fig_w = fig.Position(3);
lg.Units = 'pixels';
lg_pos = lg.Position;
row_w = (lg_pos(3) + 6) / fig_w;
leg_ax.Units = 'normalized';
ax_pos = leg_ax.Position;
leg_ax.Position = [center_x - row_w / 2, ax_pos(2), row_w, ax_pos(4)];
end

function est_w = estimate_legend_row_width(layout_width, n_items, n_cols)
%ESTIMATE_LEGEND_ROW_WIDTH Normalised width for a bottom legend row.
est_w = min(0.92 * layout_width, max(0.16, 0.042 + 0.058 * n_items));
if n_cols > 0
    est_w = min(est_w, 0.05 + 0.062 * n_cols);
end
end

function title_str = pick_color_group_title(color_info)
title_str = '';
if isfield(color_info, 'label') && ~isempty(color_info.label)
    title_str = char(color_info.label);
end
end

function title_str = group_row_title(group)
title_str = '';
if ~isfield(group, 'title') || isempty(group.title)
    return
end
if iscell(group.title)
    title_str = char(group.title{1});
else
    title_str = char(group.title);
end
end
