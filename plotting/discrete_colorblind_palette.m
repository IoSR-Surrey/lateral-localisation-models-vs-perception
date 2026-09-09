function cmap = discrete_colorblind_palette(n_colors)
%DISCRETE_COLORBLIND_PALETTE Colorblind-friendly RGB colors for discrete groups.
%
%   cmap = discrete_colorblind_palette(n_colors)
%
%   Returns an n_colors-by-3 matrix of RGB values in [0, 1]. Colours follow
%   the Okabe-Ito palette (with grey instead of black so filled markers
%   remain legible against a black edge). Extra groups cycle through the
%   base set.

if nargin < 1 || isempty(n_colors) || n_colors < 1
    n_colors = 1;
end

% Okabe-Ito palette (Wong, Nature Methods 2011).
base = [
    0, 158, 115     % Bluish Green
    230, 159,   0   % Orange
    0, 114, 178   % Blue
    240, 228,  66   % Yellow
    204, 121, 167   % Reddish Purple
    86, 180, 233    % Sky Blue
    213,  94,   0   % Vermillion
    153, 153, 153   % Black (?)
] / 255;

n_base = size(base, 1);
idx = mod(0:n_colors - 1, n_base) + 1;
cmap = base(idx, :);
end
