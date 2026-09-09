function save_figure_for_latex(fig, filepath, max_width_pt)
%SAVE_FIGURE_FOR_LATEX Export a figure as a vector PDF for LaTeX inclusion.
%
%   save_figure_for_latex(fig, filepath)
%   save_figure_for_latex(fig, filepath, max_width_pt)
%
%   Scales the figure to max_width_pt (points) while preserving aspect ratio,
%   then writes a vector PDF. Restores the on-screen figure size afterwards.

if nargin < 3 || isempty(max_width_pt)
    widths = latex_figure_widths();
    max_width_pt = widths.paper_width_pt;
end

if ~isgraphics(fig, 'figure')
    error('save_figure_for_latex:InvalidFigure', 'Expected a figure handle.');
end

[parent_dir, ~, ~] = fileparts(filepath);
if strlength(string(parent_dir)) > 0 && ~isfolder(parent_dir)
    mkdir(parent_dir);
end

orig_units = fig.Units;
orig_pos = fig.Position;
fig.Units = 'points';
pos = fig.Position;
if abs(pos(3) - max_width_pt) > 0.5
    scale = max_width_pt / pos(3);
    fig.Position = [pos(1), pos(2), max_width_pt, pos(4) * scale];
end

drawnow;
exportgraphics(fig, filepath, ...
    'ContentType', 'vector', ...
    'BackgroundColor', 'white', ...
    'Padding', 'tight');

fig.Units = orig_units;
fig.Position = orig_pos;
end
