function [listexp_view, preds_view, sem_view] = apply_simon2010_hemisphere_view( ...
    listexp_separate, hemisphere_mode, preds, sem)
%APPLY_SIMON2010_HEMISPHERE_VIEW Select separate or fold_lr view of simon2010.
%
%   Always simulate/cache on directed (separate) conditions. This helper
%   builds the analysis/plot view:
%     'separate' - return inputs unchanged
%     'fold_lr'  - load native fold_lr listexp (identical trial aggregation /
%                  SEM / nested bootstrap) and fold predictions with
%                  fold_simon2010_predictions (trial-count weighted).
%
% preds / sem are optional; pass [] or omit when only listexp is needed.

if nargin < 3
    preds = struct();
end
if nargin < 4
    sem = struct();
end
if isempty(preds)
    preds = struct();
end
if isempty(sem)
    sem = struct();
end

hemisphere_mode = char(string(hemisphere_mode));
if ~ismember(hemisphere_mode, {'fold_lr', 'separate'})
    error('apply_simon2010_hemisphere_view:BadMode', ...
        'hemisphere_mode must be ''fold_lr'' or ''separate'', got ''%s''.', ...
        hemisphere_mode);
end

if ~isfield(listexp_separate, 'simon2010_hemisphere') ...
        || ~strcmp(listexp_separate.simon2010_hemisphere, 'separate')
    error('apply_simon2010_hemisphere_view:ExpectedSeparate', ...
        'listexp_separate must use simon2010 hemisphere mode ''separate''.');
end

if strcmp(hemisphere_mode, 'separate')
    listexp_view = listexp_separate;
    preds_view = preds;
    sem_view = sem;
    return
end

% fold_lr: reuse the native loader so response means / SEM / nested
% bootstrap arrays match load_simon2010('fold_lr') exactly.
listexp_view = load_listexp_data('simon2010', 0, struct('simon2010_hemisphere', 'fold_lr'));
listexp_view.listexp_data_id = 'simon2010';
[preds_view, sem_view] = fold_simon2010_predictions( ...
    listexp_separate, listexp_view, preds, sem);
listexp_view.simon2010_hemisphere = 'fold_lr';
end
