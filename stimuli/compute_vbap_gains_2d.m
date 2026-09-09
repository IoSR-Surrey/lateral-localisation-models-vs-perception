function gain_lin = compute_vbap_gains_2d(target_az_deg, lsp_az_deg)
%COMPUTE_VBAP_GAINS_2D Pair-based 2D amplitude VBAP gains on a loudspeaker arc.
%
%   gain_lin = COMPUTE_VBAP_GAINS_2D(target_az_deg, lsp_az_deg) returns a
%   [1 x numel(lsp_az_deg)] gain vector for amplitude VBAP (Pulkki, 1997) on
%   a 1D frontal arc. Exactly two adjacent loudspeakers are active for interior
%   targets; loudspeaker-coincident targets use a single unit gain.
%
%   Angles use the codebase convention (0 = front, positive = left).

arguments
  target_az_deg (1, 1) double
  lsp_az_deg (1, :) double {mustBeNonempty}
end

lsp_az_deg = lsp_az_deg(:).';
n_lsp = numel(lsp_az_deg);
gain_lin = zeros(1, n_lsp);
tol = 1e-9;

% Coincident with a physical loudspeaker.
[~, hit_idx] = min(abs(lsp_az_deg - target_az_deg));
if abs(lsp_az_deg(hit_idx) - target_az_deg) < 1e-6
  gain_lin(hit_idx) = 1;
  return;
end

pair_idx = find(lsp_az_deg(1:end - 1) < target_az_deg & target_az_deg < lsp_az_deg(2:end), 1, 'first');
if isempty(pair_idx)
  error('compute_vbap_gains_2d: target %.4f deg is outside the loudspeaker arc.', target_az_deg);
end

l1 = unit_dir_2d(lsp_az_deg(pair_idx));
l2 = unit_dir_2d(lsp_az_deg(pair_idx + 1));
v_target = unit_dir_2d(target_az_deg);

g_pair = [l1, l2] \ v_target(:);
if any(g_pair < -tol)
  error('compute_vbap_gains_2d: negative VBAP gain for target %.4f deg.', target_az_deg);
end
g_pair = max(g_pair, 0);
g_pair = g_pair / sum(g_pair);

gain_lin(pair_idx) = g_pair(1);
gain_lin(pair_idx + 1) = g_pair(2);

n_active = nnz(gain_lin > tol);
if n_active ~= 2
  error('compute_vbap_gains_2d: expected 2 active speakers, got %d.', n_active);
end
end

function v = unit_dir_2d(az_deg)
v = [cosd(az_deg); sind(az_deg)];
end
