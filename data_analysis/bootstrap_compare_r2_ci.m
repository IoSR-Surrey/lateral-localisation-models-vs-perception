function out = bootstrap_compare_r2_ci(est_ref, est_challenger, listexp_data, opts)
%BOOTSTRAP_COMPARE_R2_CI Paired bootstrap test of R^2 difference vs reference.
%
%   out = bootstrap_compare_r2_ci(est_ref, est_challenger, listexp_data, opts)
%
% Compares two models on the same perceptual conditions using a paired
% bootstrap: each replicate resamples perceptual data once (same scheme as
% bootstrap_r2_ci) and computes R^2 for both models from that resp_b.
%
%   delta_r2 = R^2_reference - R^2_challenger  (positive => reference better)
%
% opts (all optional): n_boot (10000), ci_level (0.95), seed (42).
%
% Output: reference_r2, challenger_r2, delta_r2, delta_r2_ci, p_two,
% delta_r2_boot, n_boot, ci_level, unit.

    if nargin < 4 || isempty(opts); opts = struct(); end
    if ~isfield(opts, 'n_boot')   || isempty(opts.n_boot);   opts.n_boot = 10000; end
    if ~isfield(opts, 'ci_level') || isempty(opts.ci_level); opts.ci_level = 0.95; end
    if ~isfield(opts, 'seed')     || isempty(opts.seed);     opts.seed = 42; end

    est_r = est_ref(:);
    est_c = est_challenger(:);
    resp0 = listexp_data.avgResponseVector(:);
    if numel(est_r) ~= numel(resp0) || numel(est_c) ~= numel(resp0)
        error('bootstrap_compare_r2_ci:size', ...
            'est_ref (%d), est_challenger (%d), avgResponseVector (%d) length mismatch.', ...
            numel(est_r), numel(est_c), numel(resp0));
    end

    unit = 'condition';
    if isfield(listexp_data, 'r2_resample') ...
            && isfield(listexp_data.r2_resample, 'unit')
        unit = listexp_data.r2_resample.unit;
    end

    n_boot = opts.n_boot;
    delta_b = nan(n_boot, 1);

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
                r2_r = local_r2_from_corr(resp_b, est_r);
                r2_c = local_r2_from_corr(resp_b, est_c);
                delta_b(b) = r2_r - r2_c;
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
                r2_r = local_r2_from_corr(resp_b, est_r);
                r2_c = local_r2_from_corr(resp_b, est_c);
                delta_b(b) = r2_r - r2_c;
            end

        case 'condition'
            n = numel(resp0);
            for b = 1:n_boot
                idx = randi(n, n, 1);
                r2_r = local_r2_from_corr(resp0(idx), est_r(idx));
                r2_c = local_r2_from_corr(resp0(idx), est_c(idx));
                delta_b(b) = r2_r - r2_c;
            end

        otherwise
            error('bootstrap_compare_r2_ci:unit', 'Unknown resample unit: %s', unit);
    end

    alpha = 1 - opts.ci_level;
    lo = quantile(delta_b, alpha / 2);
    hi = quantile(delta_b, 1 - alpha / 2);

    ref_r2 = local_r2_from_corr(resp0, est_r);
    ch_r2 = local_r2_from_corr(resp0, est_c);

    out = struct();
    out.reference_r2 = ref_r2;
    out.challenger_r2 = ch_r2;
    out.delta_r2 = ref_r2 - ch_r2;
    out.delta_r2_ci = [lo, hi];
    out.p_two = 2 * min(mean(delta_b <= 0, 'omitnan'), mean(delta_b >= 0, 'omitnan'));
    out.delta_r2_boot = delta_b;
    out.n_boot = n_boot;
    out.ci_level = opts.ci_level;
    out.unit = unit;
end
