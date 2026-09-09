function fig = plot_estimatederror_grid(errors_to_plot, listexp_id, color_info, equal_xy_limits, save_opts, fixed_axis_lim, show_layout_title)
%PLOT_ESTIMATEDERROR_GRID Plot one tile per model in a single figure.
%
% Inputs
%   errors_to_plot    cell array of error structs (each compatible with
%                     plot_estimatederror_summary). One tile is drawn per
%                     entry, in the supplied order.
%   listexp_id        identifier of the listening-experiment dataset (or
%                     the combined-dataset label). Used in the layout
%                     title.
%   color_info        (optional) struct of the same shape used by
%                     plot_estimatederror_summary; controls per-point
%                     coloring (continuous or discrete). The grid wrapper
%                     also uses it to add a single shared colorbar or
%                     legend at the layout level.
%   equal_xy_limits   (optional, default false). If true, every tile's x
%                     and y axes share the same range (square axes). If
%                     false, x and y limits are unified independently
%                     across tiles (so every tile shares the same xlim
%                     with every other tile, and similarly for ylim, but
%                     a single tile's xlim and ylim may differ).
%   save_opts         (optional) struct with fields enabled (logical),
%                     output_dir (char/string), and max_width_pt (double).
%                     When enabled is true, saves a vector PDF via
%                     save_figure_for_latex after drawing.
%   fixed_axis_lim    (optional) two-element vector [lo hi], or a struct with
%                     fields lim ([lo hi]) and ticks (numeric vector), applied
%                     to every tile after limit unification.
%   show_layout_title (optional, default true) tiledlayout title above
%                     the grid ("Data from <listexp_id>").
%
% Output
%   fig             handle of the created figure.

if nargin < 3
    color_info = [];
end
if nargin < 4 || isempty(equal_xy_limits)
    equal_xy_limits = false;
end
if nargin < 5
    save_opts = [];
end
if nargin < 6
    fixed_axis_lim = [];
end
if nargin < 7 || isempty(show_layout_title)
    show_layout_title = true;
end

n = numel(errors_to_plot);
if n == 0
    fig = [];
    return
end

% Layout: fixed row count (publication default), columns sized to fit n tiles.
nr = 3;
nc = ceil(n / nr);

pub_fs = grid_publication_font_sizes();
fig_w_pt = [];
if isstruct(save_opts) && isfield(save_opts, 'enabled') && save_opts.enabled
    if isfield(save_opts, 'max_width_pt') && ~isempty(save_opts.max_width_pt)
        fig_w_pt = save_opts.max_width_pt;
    else
        widths = latex_figure_widths();
        fig_w_pt = widths.paper_width_pt;
    end
end
if isempty(fig_w_pt)
    fig = figure('Name', char("Model summary - " + string(listexp_id)));
else
  % Size the figure to the LaTeX target width before drawing so fonts and
  % layout are not squashed when exporting. Extra height for legend rows.
    n_legend_rows = estimate_bottom_legend_rows(color_info);
    tile_aspect = nr / max(nc, 1);
    fig_h_pt = fig_w_pt * tile_aspect * 1.12 + 44 + n_legend_rows * 22;
    fig = figure('Name', char("Model summary - " + string(listexp_id)), ...
        'Units', 'points', 'Position', [36, 36, fig_w_pt, fig_h_pt], ...
        'Color', 'w');
end

tl = tiledlayout(fig, nr, nc, 'TileSpacing', 'tight', 'Padding', 'compact');
if show_layout_title
    title(tl, "Data from " + string(listexp_id), 'Interpreter', 'none', ...
        'FontWeight', 'bold', 'FontSize', pub_fs.layout_title);
end
xlabel(tl, 'Perceived angle (°)', 'FontSize', pub_fs.axis_label);
ylabel(tl, 'Estimated angle (°)', 'FontSize', pub_fs.axis_label);

tile_axes = gobjects(n, 1);
for k = 1:n
    tile_axes(k) = nexttile(tl);
    plot_estimatederror_summary(errors_to_plot{k}, listexp_id, color_info, ...
        tile_axes(k), equal_xy_limits);
end

% Unify the axis limits across all tiles so every subplot uses the same
% x range and the same y range. By default x and y are unified
% independently. When equal_xy_limits is true, both axes are unified to
% the combined union of x and y ranges (square axes).
xall = arrayfun(@(a) xlim(a), tile_axes, 'UniformOutput', false);
yall = arrayfun(@(a) ylim(a), tile_axes, 'UniformOutput', false);
xall = vertcat(xall{:});
yall = vertcat(yall{:});
xlo = min(xall(:,1)); xhi = max(xall(:,2));
ylo = min(yall(:,1)); yhi = max(yall(:,2));
if equal_xy_limits
    lo = min(xlo, ylo); hi = max(xhi, yhi);
    xlo = lo; xhi = hi;
    ylo = lo; yhi = hi;
end
if isfinite(xlo) && isfinite(xhi) && xhi > xlo
    for k = 1:n
        xlim(tile_axes(k), [xlo, xhi]);
    end
end
if isfinite(ylo) && isfinite(yhi) && yhi > ylo
    for k = 1:n
        ylim(tile_axes(k), [ylo, yhi]);
    end
end

[fixed_lim, fixed_ticks] = parse_fixed_axis_lim(fixed_axis_lim);
if ~isempty(fixed_lim) && numel(fixed_lim) == 2 ...
        && isfinite(fixed_lim(1)) && isfinite(fixed_lim(2)) ...
        && fixed_lim(2) > fixed_lim(1)
    for k = 1:n
        xlim(tile_axes(k), fixed_lim);
        ylim(tile_axes(k), fixed_lim);
    end
end
if ~isempty(fixed_ticks)
    for k = 1:n
        tile_axes(k).XTick = fixed_ticks;
        tile_axes(k).YTick = fixed_ticks;
    end
end

% Hide redundant y tick labels on interior columns. Every tile keeps its
% x tick labels. Shared xlim/ylim keep auto-chosen tick positions aligned.
for k = 1:n
    col = mod(k-1, nc) + 1;
    if col > 1
        tile_axes(k).YTickLabel = [];
    end
end

layout_grid_bottom_legends(tl, tile_axes, color_info, pub_fs);

if isstruct(save_opts) && isfield(save_opts, 'enabled') && save_opts.enabled
    if ~isfield(save_opts, 'output_dir') || isempty(save_opts.output_dir)
        error('plot_estimatederror_grid:SaveOpts', ...
            'save_opts.output_dir is required when save_opts.enabled is true.');
    end
    if ~isfield(save_opts, 'max_width_pt') || isempty(save_opts.max_width_pt)
        widths = latex_figure_widths();
        save_opts.max_width_pt = widths.paper_width_pt;
    end
    safe_id = regexprep(char(string(listexp_id)), '[^\w-]', '_');
    pdf_path = fullfile(save_opts.output_dir, ['model_summary_' safe_id '.pdf']);
    save_figure_for_latex(fig, pdf_path, save_opts.max_width_pt);
    fprintf('Saved figure PDF to: %s\n', pdf_path);
end
end

function [lim_vec, tick_vec] = parse_fixed_axis_lim(fixed_axis_lim)
lim_vec = [];
tick_vec = [];
if isempty(fixed_axis_lim)
    return
end
if isstruct(fixed_axis_lim)
    if isfield(fixed_axis_lim, 'lim') && ~isempty(fixed_axis_lim.lim)
        lim_vec = fixed_axis_lim.lim(:)';
    end
    if isfield(fixed_axis_lim, 'ticks') && ~isempty(fixed_axis_lim.ticks)
        tick_vec = fixed_axis_lim.ticks(:)';
    end
elseif isnumeric(fixed_axis_lim) && numel(fixed_axis_lim) == 2
    lim_vec = fixed_axis_lim(:)';
end
end
