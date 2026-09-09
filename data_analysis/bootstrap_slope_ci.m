function out = bootstrap_slope_ci(est_angle, listexp_data, opts)
%BOOTSTRAP_SLOPE_CI Bootstrap confidence interval for regression slope.
%
%   out = bootstrap_slope_ci(est_angle, listexp_data, opts)
%
% Quantifies uncertainty of the OLS slope beta1 in the linear fit
%   estimated_angle ~ perceived_angle
% (equivalent to fitlm(perceived, estimated) in func_errormetrics).
% beta1 < 1 indicates compressed model dynamic range vs perceptual data.
%
% Resampling scheme matches bootstrap_r2_ci (listexp_data.r2_resample.unit):
%   'nested', 'trial', 'condition' — see bootstrap_r2_ci for array layouts.
%
% opts (all optional):
%   n_boot   number of bootstrap replicates (default 10000)
%   ci_level confidence level for the interval (default 0.95)
%   seed     RNG seed for reproducibility (default 42)
%
% Output struct fields: slope, slope_ci ([lo hi]), slope_se, slope_boot,
% p_one (two-sided bootstrap p for H0: slope = 1), n_boot, ci_level, unit.

    if nargin < 3 || isempty(opts); opts = struct(); end
    if ~isfield(opts, 'n_boot')   || isempty(opts.n_boot);   opts.n_boot = 10000; end
    if ~isfield(opts, 'ci_level') || isempty(opts.ci_level); opts.ci_level = 0.95; end
    if ~isfield(opts, 'seed')     || isempty(opts.seed);     opts.seed = 42; end

    est = est_angle(:);
    resp0 = listexp_data.avgResponseVector(:);
    if numel(est) ~= numel(resp0)
        error('bootstrap_slope_ci:size', ...
            'est_angle (%d) and avgResponseVector (%d) length mismatch.', ...
            numel(est), numel(resp0));
    end

    unit = 'condition';
    if isfield(listexp_data, 'r2_resample') ...
            && isfield(listexp_data.r2_resample, 'unit')
        unit = listexp_data.r2_resample.unit;
    end

    n_boot = opts.n_boot;
    slopeb = nan(n_boot, 1);

    rng_state = rng;
    cleanup_rng = onCleanup(@() rng(rng_state));
    rng(opts.seed, 'twister');

    switch unit
        case 'nested'
            T = listexp_data.r2_resample.trials;
            cnt = listexp_data.r2_resample.counts;
            [nCond, nUnit, maxT] = size(T);
            step = nCond * nUnit;
            rows = repmat((1:nCond)', 1, nUnit, maxT);
            cols = repmat((0:nUnit-1) * nCond, nCond, 1, maxT);
            base_idx = rows + cols;
            [~, ~, page_grid] = ndgrid(1:nCond, 1:nUnit, 1:maxT);
            for b = 1:n_boot
                usel = randi(nUnit, 1, nUnit);
                Ts = T(:, usel, :);
                cs = cnt(:, usel);
                cs3 = reshape(cs, nCond, nUnit, 1);
                ridx = floor(rand(nCond, nUnit, maxT) .* cs3) + 1;
                ridx(ridx < 1) = 1;
                vals = Ts(base_idx + (ridx - 1) * step);
                vals(page_grid > cs3) = 0;
                unit_means = sum(vals, 3) ./ cs;
                unit_means(cs == 0) = NaN;
                resp_b = mean(unit_means, 2, 'omitnan');
                slopeb(b) = local_slope(resp_b, est);
            end

        case 'trial'
            T = listexp_data.r2_resample.trials;
            cnt = listexp_data.r2_resample.counts(:);
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
                slopeb(b) = local_slope(resp_b, est);
            end

        case 'condition'
            n = numel(resp0);
            for b = 1:n_boot
                idx = randi(n, n, 1);
                slopeb(b) = local_slope(resp0(idx), est(idx));
            end

        otherwise
            error('bootstrap_slope_ci:unit', 'Unknown resample unit: %s', unit);
    end

    alpha = 1 - opts.ci_level;
    lo = quantile(slopeb, alpha / 2);
    hi = quantile(slopeb, 1 - alpha / 2);

    out = struct();
    out.slope = local_slope(resp0, est);
    out.slope_ci = [lo, hi];
    out.slope_se = std(slopeb, 'omitnan');
    out.slope_boot = slopeb;
    out.p_one = 2 * min(mean(slopeb <= 1, 'omitnan'), mean(slopeb >= 1, 'omitnan'));
    out.n_boot = n_boot;
    out.ci_level = opts.ci_level;
    out.unit = unit;
end

function slope = local_slope(x, y)
% OLS slope of y ~ x (perceived = x, estimated = y).
    ok = ~isnan(x) & ~isnan(y);
    if nnz(ok) < 3
        slope = NaN;
        return;
    end
    xv = x(ok);
    yv = y(ok);
    vx = var(xv, 1);
    if vx == 0 || ~isfinite(vx)
        slope = NaN;
        return;
    end
    cxy = cov(xv, yv, 1);
    slope = cxy(1, 2) / vx;
end
