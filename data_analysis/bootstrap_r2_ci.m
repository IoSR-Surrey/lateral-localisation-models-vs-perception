function out = bootstrap_r2_ci(est_angle, listexp_data, opts)
%BOOTSTRAP_R2_CI Bootstrap confidence interval for a model fit's R^2.
%
%   out = bootstrap_r2_ci(est_angle, listexp_data, opts)
%
% Quantifies the uncertainty of the coefficient of determination (R^2)
% between a model's predicted angles (est_angle) and the perceptual data
% (listexp_data.avgResponseVector). For a single-predictor linear fit,
% R^2 == corr(x, y)^2, which equals the LinearModel Rsquared.Ordinary used
% elsewhere; the bootstrap replicates use corr()^2 for speed.
%
% The resampling scheme is taken from listexp_data.r2_resample.unit:
%   'nested'    Resample units (listeners/subjects) with replacement, then
%               resample repetitions/trials within each chosen unit x
%               condition. Requires padded arrays aligned to
%               avgResponseVector ordering:
%                   listexp_data.r2_resample.trials [nCond x nUnit x maxT]
%                   listexp_data.r2_resample.counts [nCond x nUnit]
%   'trial'     Resample trials within each condition, ignoring grouping.
%                   listexp_data.r2_resample.trials [nCond x maxT]
%                   listexp_data.r2_resample.counts [nCond x 1]
%   'condition' Case bootstrap: resample the (response, prediction) pairs.
%               This is also the default when r2_resample is absent.
%
% opts (all optional):
%   n_boot   number of bootstrap replicates (default 10000)
%   ci_level confidence level for the interval (default 0.95)
%   seed     RNG seed for reproducibility (default 42)
%
% Output struct fields: r2 (point estimate), r2_ci ([lo hi]), r2_se,
% r2_boot (replicate values), n_boot, ci_level, unit.

    if nargin < 3 || isempty(opts); opts = struct(); end
    if ~isfield(opts, 'n_boot')   || isempty(opts.n_boot);   opts.n_boot = 10000; end
    if ~isfield(opts, 'ci_level') || isempty(opts.ci_level); opts.ci_level = 0.95; end
    if ~isfield(opts, 'seed')     || isempty(opts.seed);     opts.seed = 42; end

    est = est_angle(:);
    resp0 = listexp_data.avgResponseVector(:);
    if numel(est) ~= numel(resp0)
        error('bootstrap_r2_ci:size', ...
            'est_angle (%d) and avgResponseVector (%d) length mismatch.', ...
            numel(est), numel(resp0));
    end

    unit = 'condition';
    if isfield(listexp_data, 'r2_resample') ...
            && isfield(listexp_data.r2_resample, 'unit')
        unit = listexp_data.r2_resample.unit;
    end

    n_boot = opts.n_boot;
    r2b = nan(n_boot, 1);

    % Reproducible RNG, restored on exit so callers are unaffected.
    rng_state = rng;
    cleanup_rng = onCleanup(@() rng(rng_state));
    rng(opts.seed, 'twister');

    switch unit
        case 'nested'
            T = listexp_data.r2_resample.trials;    % [nCond x nUnit x maxT]
            cnt = listexp_data.r2_resample.counts;  % [nCond x nUnit]
            [nCond, nUnit, maxT] = size(T);
            step = nCond * nUnit;
            % Constant linear-index base for an [nCond x nUnit x maxT] array.
            rows = repmat((1:nCond)', 1, nUnit, maxT);
            cols = repmat((0:nUnit-1) * nCond, nCond, 1, maxT);
            base_idx = rows + cols;
            [~, ~, page_grid] = ndgrid(1:nCond, 1:nUnit, 1:maxT);
            for b = 1:n_boot
                usel = randi(nUnit, 1, nUnit);
                Ts = T(:, usel, :);
                cs = cnt(:, usel);
                cs3 = reshape(cs, nCond, nUnit, 1);
                % Trial indices in 1..cs (empty cells -> 1, masked out below).
                ridx = floor(rand(nCond, nUnit, maxT) .* cs3) + 1;
                ridx(ridx < 1) = 1;
                vals = Ts(base_idx + (ridx - 1) * step);
                vals(page_grid > cs3) = 0;
                unit_means = sum(vals, 3) ./ cs;    % [nCond x nUnit]
                unit_means(cs == 0) = NaN;
                resp_b = mean(unit_means, 2, 'omitnan');
                r2b(b) = local_r2_from_corr(resp_b, est);
            end

        case 'trial'
            T = listexp_data.r2_resample.trials;        % [nCond x maxT]
            cnt = listexp_data.r2_resample.counts(:);   % [nCond x 1]
            [nCond, maxT] = size(T);
            rows = repmat((1:nCond)', 1, maxT);
            col_grid = repmat(1:maxT, nCond, 1);
            for b = 1:n_boot
                ridx = floor(rand(nCond, maxT) .* cnt) + 1;
                ridx(ridx < 1) = 1;
                vals = T(rows + (ridx - 1) * nCond);
                vals(col_grid > cnt) = 0;
                resp_b = sum(vals, 2) ./ cnt;
                resp_b(cnt == 0) = NaN;
                r2b(b) = local_r2_from_corr(resp_b, est);
            end

        case 'condition'
            n = numel(resp0);
            for b = 1:n_boot
                idx = randi(n, n, 1);
                r2b(b) = local_r2_from_corr(resp0(idx), est(idx));
            end

        otherwise
            error('bootstrap_r2_ci:unit', 'Unknown resample unit: %s', unit);
    end

    alpha = 1 - opts.ci_level;
    lo = quantile(r2b, alpha / 2);
    hi = quantile(r2b, 1 - alpha / 2);

    out = struct();
    out.r2 = local_r2_from_corr(resp0, est);
    out.r2_ci = [lo, hi];
    out.r2_se = std(r2b, 'omitnan');
    out.r2_boot = r2b;
    out.n_boot = n_boot;
    out.ci_level = opts.ci_level;
    out.unit = unit;
end
