function widths = latex_figure_widths()
%LATEX_FIGURE_WIDTHS Maximum figure widths (pt) for LaTeX manuscript figures.
%
%   widths.textwidth_pt           LaTeX \textwidth (two-column full width).
%   widths.paper_width_pt         Export width for full-width figures. Slightly
%                                 below textwidth so \includegraphics{width=\textwidth}
%                                 does not overfill (empirical margin ~85 pt).
%   widths.single_column_width_pt Single-column width (\columnwidth).

widths.textwidth_pt = 512.1496;
widths.paper_width_pt = widths.textwidth_pt - 2.78; % - 85.08018;
widths.single_column_width_pt = 247.53897;
end
