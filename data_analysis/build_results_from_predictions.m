function [results, workspace_vars] = build_results_from_predictions( ...
    preds_mean, preds_sem, listexp_data, cfg)
%BUILD_RESULTS_FROM_PREDICTIONS Create error structs from mean predictions.
%   Returns a results struct keyed by model_id and a workspace_vars struct
%   suitable for saving (est_angle_*, error_*, time_*, sem fields).

results = struct();
workspace_vars = struct();
fit_ci_opts = cfg.fit_ci_opts;

model_specs = { ...
    'lindemann1986', 'est_angle_lindemann1986', 'time_lindemann1986_s', cfg.run_lindemann1986; ...
    'breebaart2001', 'est_angle_breebaart2001', 'time_breebaart2001_s', cfg.run_breebaart2001; ...
    'faller2004', 'est_angle_faller2004', 'time_faller2004_s', cfg.run_faller2004; ...
    'may2011', 'est_angle_may2011', 'time_may2011_s', cfg.run_may2011; ...
    'dietz2011', 'est_angle_dietz2011', 'time_dietz2011_s', cfg.run_dietz2011; ...
    'takanen2013', 'est_angle_takanen2013', 'time_takanen2013_s', cfg.run_takanen2013; ...
    'llado2025', 'est_angle_llado2025', 'time_llado2025_s', cfg.run_llado2025; ...
    'kurz2017', 'est_angle_kurz2017', 'time_kurz2017_s', cfg.run_extended_re; ...
    'stitt2016', 'est_angle_stitt2016', 'time_stitt2016_s', cfg.run_extended_re; ...
    'rE', 'est_angle_rE', 'time_rE_s', cfg.run_extended_re; ...
    'saddler2024', 'est_angle_expected_saddler2024', 'time_saddler2024_s', cfg.run_saddler2024; ...
    'wang2026', 'est_angle_wang2026', 'time_wang2026_s', cfg.run_wang2026; ...
    'vecchiotti2019', 'est_angle_vecchiotti2019', 'time_vecchiotti2019_s', cfg.run_vecchiotti2019 ...
    };

for ridx = 1:size(model_specs, 1)
    model_id = model_specs{ridx, 1};
    pred_field = model_specs{ridx, 2};
    time_field = model_specs{ridx, 3};
    enabled = model_specs{ridx, 4};
    if ~enabled || ~isfield(preds_mean, pred_field)
        continue
    end

    est_angle = preds_mean.(pred_field)(:);
    workspace_vars.(pred_field) = est_angle;

    if ~isempty(time_field) && isfield(preds_mean, time_field)
        workspace_vars.(time_field) = preds_mean.(time_field);
    end

    sem_field = [pred_field '_sem'];
    if isfield(preds_sem, sem_field)
        workspace_vars.(sem_field) = preds_sem.(sem_field)(:);
    end

    if strcmp(model_id, 'vecchiotti2019') && isfield(preds_mean, 'vecchiotti_error')
        err = struct('error', preds_mean.vecchiotti_error, ...
            'model_id', preds_mean.vecchiotti_model_id);
        err = attach_fit_ci_local(err, est_angle, listexp_data, ...
            cfg.compute_r2_ci, cfg.compute_slope_ci, fit_ci_opts);
    else
        err = make_error_struct_local(est_angle, listexp_data, model_id, ...
            cfg.compute_r2_ci, cfg.compute_slope_ci, fit_ci_opts);
    end

    if isfield(preds_sem, sem_field)
        err.est_yerr = preds_sem.(sem_field)(:);
    end

    results.(model_id) = err;
    workspace_vars.(['error_' model_id]) = err;
end

if cfg.run_saddler2024 && isfield(preds_mean, 'est_angle_saddler2024')
    extra_fields = { ...
        'est_angle_saddler2024', ...
        'est_class_index_saddler2024', ...
        'est_angle_saddler2024_per_model', ...
        'est_angle_expected_saddler2024_per_model', ...
        'est_class_index_saddler2024_per_model'};
    for eidx = 1:numel(extra_fields)
        field_name = extra_fields{eidx};
        if isfield(preds_mean, field_name)
            workspace_vars.(field_name) = preds_mean.(field_name);
        end
    end
    if isfield(preds_mean, 'est_angle_expected_saddler2024')
        workspace_vars.est_angle_expected_saddler2024 = preds_mean.est_angle_expected_saddler2024;
    end
end

if cfg.run_vecchiotti2019
    if isfield(preds_mean, 'est_angle_expected_vecchiotti2019')
        workspace_vars.est_angle_expected_vecchiotti2019 = preds_mean.est_angle_expected_vecchiotti2019;
    end
    if isfield(preds_mean, 'est_class_index_vecchiotti2019')
        workspace_vars.est_class_index_vecchiotti2019 = preds_mean.est_class_index_vecchiotti2019;
    end
    if isfield(preds_mean, 'est_angle_raw_vecchiotti2019')
        workspace_vars.est_angle_raw_vecchiotti2019 = preds_mean.est_angle_raw_vecchiotti2019;
    end
    if isfield(preds_mean, 'vecchiotti_max_prob')
        workspace_vars.vecchiotti_max_prob = preds_mean.vecchiotti_max_prob;
    end
    if isfield(preds_mean, 'vecchiotti_prob_entropy')
        workspace_vars.vecchiotti_prob_entropy = preds_mean.vecchiotti_prob_entropy;
    end
end
end

function err = make_error_struct_local(est_angle, listexp_data, model_id, ...
        compute_r2_ci, compute_slope_ci, fit_ci_opts)
err = struct();
err.error = func_errormetrics(est_angle, listexp_data);
err.model_id = model_id;
err = attach_fit_ci_local(err, est_angle, listexp_data, ...
    compute_r2_ci, compute_slope_ci, fit_ci_opts);
end

function err = attach_fit_ci_local(err, est_angle, listexp_data, ...
        compute_r2_ci, compute_slope_ci, fit_ci_opts)
if compute_r2_ci
    err.r2_ci = bootstrap_r2_ci(est_angle, listexp_data, fit_ci_opts);
end
if compute_slope_ci
    err.slope_ci = bootstrap_slope_ci(est_angle, listexp_data, fit_ci_opts);
end
end
