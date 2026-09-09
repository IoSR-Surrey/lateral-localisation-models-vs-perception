function r2 = local_r2_from_corr(x, y)
%LOCAL_R2_FROM_CORR Squared Pearson correlation (ordinary R^2 for one predictor).
    ok = ~isnan(x) & ~isnan(y);
    if nnz(ok) < 3
        r2 = NaN;
        return;
    end
    c = corr(x(ok), y(ok));
    r2 = c^2;
end
