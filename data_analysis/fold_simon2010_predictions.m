function [preds_out, sem_out] = fold_simon2010_predictions( ...
    listexp_separate, listexp_folded, preds_in, sem_in)
%FOLD_SIMON2010_PREDICTIONS Map separate-hemisphere preds onto fold_lr cells.
%
%   [preds_out, sem_out] = fold_simon2010_predictions( ...
%       listexp_separate, listexp_folded, preds_in, sem_in)
%
% For each folded (left) condition, find the matching left/right directed
% conditions in listexp_separate and combine predictions as the trial-count
% weighted average of pred_L and -pred_R:
%
%   pred_fold = (n_L * pred_L + n_R * (-pred_R)) / (n_L + n_R)
%
% That mirrors pooling L + mirrored-R response trials (each trial inherits
% its hemisphere's model prediction). Scalar / non-condition fields are
% copied unchanged. Optional sem_in fields named <pred>_sem are combined as
% hypot(w_L * sem_L, w_R * sem_R).

if nargin < 3 || isempty(preds_in)
    preds_in = struct();
end
if nargin < 4 || isempty(sem_in)
    sem_in = struct();
end

if ~isfield(listexp_separate, 'simon2010_hemisphere') ...
        || ~strcmp(listexp_separate.simon2010_hemisphere, 'separate')
    error('fold_simon2010_predictions:ExpectedSeparate', ...
        'listexp_separate must be simon2010 with hemisphere mode ''separate''.');
end
if ~isfield(listexp_folded, 'simon2010_hemisphere') ...
        || ~strcmp(listexp_folded.simon2010_hemisphere, 'fold_lr')
    error('fold_simon2010_predictions:ExpectedFold', ...
        'listexp_folded must be simon2010 with hemisphere mode ''fold_lr''.');
end

avg_sep = listexp_separate.avgResponse;
avg_fold = listexp_folded.avgResponse;
n_sep = size(avg_sep, 1);
n_fold = size(avg_fold, 1);
n_trials_sep = listexp_separate.nTrials(:);
if numel(n_trials_sep) ~= n_sep
    error('fold_simon2010_predictions:nTrials', ...
        'separate nTrials length (%d) != avgResponse (%d).', ...
        numel(n_trials_sep), n_sep);
end

[idx_left, idx_right, w_left, w_right] = match_fold_to_separate_indices( ...
    avg_sep, avg_fold, n_trials_sep);

preds_out = struct();
pred_fields = fieldnames(preds_in);
for i = 1:numel(pred_fields)
    fname = pred_fields{i};
    val = preds_in.(fname);
    if isnumeric(val) && isvector(val) && numel(val) == n_sep
        preds_out.(fname) = combine_left_right( ...
            val(:), idx_left, idx_right, w_left, w_right, n_fold, true);
    else
        preds_out.(fname) = val;
    end
end

sem_out = struct();
sem_fields = fieldnames(sem_in);
for i = 1:numel(sem_fields)
    fname = sem_fields{i};
    val = sem_in.(fname);
    if isnumeric(val) && isvector(val) && numel(val) == n_sep
        sem_out.(fname) = combine_left_right_sem( ...
            val(:), idx_left, idx_right, w_left, w_right, n_fold);
    else
        sem_out.(fname) = val;
    end
end
end

function [idx_left, idx_right, w_left, w_right] = match_fold_to_separate_indices( ...
    avg_sep, avg_fold, n_trials_sep)
% Match each folded cell to left (+az) and right (-az) separate rows.
n_fold = size(avg_fold, 1);
idx_left = zeros(n_fold, 1);
idx_right = zeros(n_fold, 1);
w_left = zeros(n_fold, 1);
w_right = zeros(n_fold, 1);

for i = 1:n_fold
    icld = avg_fold(i, 1);
    ictd = avg_fold(i, 2);
    az1 = avg_fold(i, 3);
    az2 = avg_fold(i, 4);

    i_l = find_condition_row(avg_sep, icld, ictd, az1, az2);
    i_r = find_condition_row(avg_sep, icld, ictd, -az1, -az2);
    if i_l == 0 && i_r == 0
        error('fold_simon2010_predictions:NoMatch', ...
            ['No separate condition for folded ICLD=%.3g ICTD=%.3g ' ...
            'az=[%.3g %.3g].'], icld, ictd, az1, az2);
    end
    idx_left(i) = i_l;
    idx_right(i) = i_r;
    if i_l > 0
        w_left(i) = n_trials_sep(i_l);
    end
    if i_r > 0
        w_right(i) = n_trials_sep(i_r);
    end
    if w_left(i) + w_right(i) <= 0
        error('fold_simon2010_predictions:ZeroWeight', ...
            'Folded condition %d has zero trial weight.', i);
    end
end
end

function idx = find_condition_row(avg, icld, ictd, az1, az2)
tol = 1e-9;
sel = abs(avg(:, 1) - icld) < tol ...
    & abs(avg(:, 2) - ictd) < tol ...
    & abs(avg(:, 3) - az1) < tol ...
    & abs(avg(:, 4) - az2) < tol;
idx = find(sel, 1);
if isempty(idx)
    idx = 0;
end
end

function out = combine_left_right(vec, idx_left, idx_right, w_left, w_right, n_fold, mirror_right)
out = nan(n_fold, 1);
for i = 1:n_fold
    num = 0;
    den = w_left(i) + w_right(i);
    if idx_left(i) > 0 && w_left(i) > 0
        num = num + w_left(i) * vec(idx_left(i));
    end
    if idx_right(i) > 0 && w_right(i) > 0
        v_r = vec(idx_right(i));
        if mirror_right
            v_r = -v_r;
        end
        num = num + w_right(i) * v_r;
    end
    out(i) = num / den;
end
end

function out = combine_left_right_sem(vec, idx_left, idx_right, w_left, w_right, n_fold)
% SEM of weighted mean of independent L and mirrored-R estimates.
out = nan(n_fold, 1);
for i = 1:n_fold
    den = w_left(i) + w_right(i);
    w_l = w_left(i) / den;
    w_r = w_right(i) / den;
    s2 = 0;
    if idx_left(i) > 0 && w_left(i) > 0 && isfinite(vec(idx_left(i)))
        s2 = s2 + (w_l * vec(idx_left(i)))^2;
    end
    if idx_right(i) > 0 && w_right(i) > 0 && isfinite(vec(idx_right(i)))
        s2 = s2 + (w_r * vec(idx_right(i)))^2;
    end
    out(i) = sqrt(s2);
end
end
