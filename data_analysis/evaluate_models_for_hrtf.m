function preds = evaluate_models_for_hrtf(obj, sofa_name, listexp_data, listexp_data_id, cfg)
%EVALUATE_MODELS_FOR_HRTF Run stimulus generation and models for one HRTF.
%   preds = EVALUATE_MODELS_FOR_HRTF(obj, sofa_name, listexp_data,
%   listexp_data_id, cfg) returns a struct of est_angle_* vectors (and
%   optional timing fields) for each enabled model in cfg.
%
%   Optional cfg fields:
%     models_to_compute  Cell of model ids to evaluate (subset of enabled).
%     skip_geometry_models  When true, skip kurz2017/stitt2016/rE evaluation.

if isfield(cfg, 'models_to_compute') && ~isempty(cfg.models_to_compute)
    models_to_run = cfg.models_to_compute;
    if isfield(cfg, 'skip_geometry_models') && cfg.skip_geometry_models
        models_to_run = setdiff(models_to_run, geometry_model_ids(), 'stable');
    end
    cfg = restrict_eval_cfg_to_models(cfg, models_to_run);
elseif isfield(cfg, 'skip_geometry_models') && cfg.skip_geometry_models
    cfg.run_extended_re = false;
end

needs_hrtf_stimuli = cfg.run_lindemann1986 || cfg.run_breebaart2001 || ...
    cfg.run_faller2004 || cfg.run_may2011 || cfg.run_dietz2011 || ...
    cfg.run_takanen2013 || cfg.run_llado2025 || ...
    cfg.run_saddler2024 || cfg.run_wang2026 || cfg.run_vecchiotti2019;

preds = struct();
if ~needs_hrtf_stimuli && ~cfg.run_extended_re
    return;
end

fs_native = obj.Data.SamplingRate;
obj_work = obj;
fs = fs_native;
if strcmp(listexp_data_id, 'desena2013')
    fs = 44100;
    if obj_work.Data.SamplingRate ~= fs
        obj_work = SOFAresample(obj_work, fs);
    end
elseif strcmp(listexp_data_id, 'llado2026')
    fs = 48000;
    if obj_work.Data.SamplingRate ~= fs
        obj_work = SOFAresample(obj_work, fs);
    end
end

lvl_dB = cfg.lvl_dB;
if isfield(listexp_data, 'frank2013_presentation_lvl_dBA')
    lvl_dB = listexp_data.frank2013_presentation_lvl_dBA;
end
fLow = cfg.fLow;
fHigh = cfg.fHigh;
spacingERB = cfg.spacingERB;
hop_size_in_ms = 10;

if needs_hrtf_stimuli
    stimulus_id = listexp_data_id;
    stim_opts = struct();
    if isfield(cfg, 'frank2013_single_burst') && cfg.frank2013_single_burst
        stim_opts.frank2013_single_burst = true;
    end
    bin_signal_matrix = generate_stimuli(stimulus_id, obj_work, listexp_data, lvl_dB, stim_opts);
    bin_signal_all = reshape(bin_signal_matrix, [], 1);
    nSignals = numel(bin_signal_all);

    cal_noise = randn(fs / 4, 1);
    w = cos(2 * pi * 25 * (1 / fs:1 / fs:1 / 100)').^2;
    cal_noise(1:length(w)) = cal_noise(1:length(w)) .* w(end:-1:1);
    cal_noise(end - length(w) + 1:end) = cal_noise(end - length(w) + 1:end) .* w;

    sig_uncorr = func_binauralise_lsp_signals(cal_noise', 0, 2, obj_work, fs);
    target_rms = mean(rms(sig_uncorr));
    norm_factors = target_rms ./ rms(sig_uncorr);

    bin_signal_all_norm = cell(nSignals, 1);
    for isig = 1:nSignals
        bin_signal_all_norm{isig} = bin_signal_all{isig} .* norm_factors;
    end

    templates = ensure_cached_hrtf_templates(obj_work, fs, sofa_name, cfg);
    template_lindemann1986 = template_for_enabled_model(templates, 'template_lindemann1986', cfg.run_lindemann1986);
    template_breebaart2001 = template_for_enabled_model(templates, 'template_breebaart2001', cfg.run_breebaart2001);
    template_faller2004 = template_for_enabled_model(templates, 'template_faller2004', cfg.run_faller2004);
    template_dietz2011 = template_for_enabled_model(templates, 'template_dietz2011', cfg.run_dietz2011);
    template_llado2025 = template_for_enabled_model(templates, 'template_llado2025', cfg.run_llado2025);

    window_size = size(bin_signal_all{1}, 1);
    hop_size = round(fs * hop_size_in_ms / 1000);
    bin_signal_length = size(bin_signal_all{1}, 1);
    Nwindows = max(0, floor((bin_signal_length - window_size) / hop_size) + 1);
else
    nSignals = numel(listexp_data.avgResponseVector);
    bin_signal_all_norm = {};
    template_lindemann1986 = [];
    template_breebaart2001 = [];
    template_faller2004 = [];
    template_dietz2011 = [];
    template_llado2025 = [];
    window_size = 0;
    hop_size = 0;
    Nwindows = 0;
end

use_parallel = true;
if isfield(cfg, 'use_parallel') && ~isempty(cfg.use_parallel)
    use_parallel = logical(cfg.use_parallel);
end

if cfg.run_lindemann1986
    disp("~~~ Evaluating lindemann1986 ~~~")
    tic
    preds.est_angle_lindemann1986 = eval_lindemann1986(bin_signal_all_norm, fs, ...
        template_lindemann1986, use_parallel);
    preds.time_lindemann1986_s = toc;
    fprintf('lindemann1986 elapsed: %.3f s\n', preds.time_lindemann1986_s);
end

if cfg.run_breebaart2001
    disp("~~~ Evaluating breebaart2001 ~~~")
    tic
    preds.est_angle_breebaart2001 = eval_breebaart2001(bin_signal_all_norm, fs, ...
        template_breebaart2001, fLow, fHigh, window_size, hop_size, Nwindows, use_parallel);
    preds.time_breebaart2001_s = toc;
    fprintf('breebaart2001 elapsed: %.3f s\n', preds.time_breebaart2001_s);
end

if cfg.run_faller2004
    disp("~~~ Evaluating faller2004 ~~~")
    tic
    preds.est_angle_faller2004 = eval_faller2004(bin_signal_all_norm, fs, ...
        template_faller2004, fLow, fHigh, spacingERB, hop_size_in_ms, use_parallel);
    preds.time_faller2004_s = toc;
    fprintf('faller2004 elapsed: %.3f s\n', preds.time_faller2004_s);
end

if cfg.run_may2011
    disp("~~~ Evaluating may2011 ~~~")
    tic
    preds.est_angle_may2011 = eval_may2011(bin_signal_all_norm, fs, use_parallel);
    preds.time_may2011_s = toc;
    fprintf('may2011 elapsed: %.3f s\n', preds.time_may2011_s);
end

if cfg.run_dietz2011
    disp("~~~ Evaluating dietz2011 ~~~")
    tic
    preds.est_angle_dietz2011 = eval_dietz2011(bin_signal_all_norm, fs, ...
        template_dietz2011, window_size, hop_size, Nwindows, use_parallel);
    preds.time_dietz2011_s = toc;
    fprintf('dietz2011 elapsed: %.3f s\n', preds.time_dietz2011_s);
end

if cfg.run_takanen2013
    disp("~~~ Evaluating takanen2013 ~~~")
    tic
    preds.est_angle_takanen2013 = eval_takanen2013(bin_signal_all_norm, fs, ...
        window_size, hop_size, Nwindows, listexp_data_id, use_parallel);
    preds.time_takanen2013_s = toc;
    fprintf('takanen2013 elapsed: %.3f s\n', preds.time_takanen2013_s);
end

if cfg.run_llado2025
    disp("~~~ Evaluating llado2025 ~~~")
    tic
    preds.est_angle_llado2025 = eval_desena2020(bin_signal_all_norm, fs, ...
        template_llado2025, window_size, hop_size, Nwindows, use_parallel);
    preds.time_llado2025_s = toc;
    fprintf('llado2025 elapsed: %.3f s\n', preds.time_llado2025_s);
end

if cfg.run_extended_re
    re_cfg = struct();
    re_cfg.speed_of_sound_mps = 345;
    re_cfg.delay_weight_db_per_s = -1000; % Original Kurz & Frank (2017) uses -250, but Frank (2023) uses -1000, which seems to fit the data better
    re_cfg.alpha = 0.1;
    re_cfg.sign_correction = re_get_sign_correction(listexp_data_id);
    re_cfg.fs = fs;

    disp("~~~ Evaluating extended rE models (kurz2017, stitt2016, rE) ~~~")
    re_out = eval_extended_re(listexp_data_id, listexp_data, re_cfg, nSignals);
    preds.est_angle_kurz2017 = re_out.kurz2017;
    preds.est_angle_stitt2016 = re_out.stitt2016;
    preds.est_angle_rE = re_out.rE;
    preds.time_kurz2017_s = re_out.time_kurz2017_s;
    preds.time_stitt2016_s = re_out.time_stitt2016_s;
    preds.time_rE_s = re_out.time_rE_s;
    fprintf('kurz2017 elapsed: %.3f s\n', preds.time_kurz2017_s);
    fprintf('stitt2016 elapsed: %.3f s\n', preds.time_stitt2016_s);
    fprintf('rE elapsed: %.3f s\n', preds.time_rE_s);
end

if cfg.run_saddler2024
    disp("~~~ Evaluating saddler2024 ~~~")
    tic
    saddler_out = eval_saddler2024(bin_signal_all_norm, fs, cfg.pyFolder, cfg.venvPython);
    preds.time_saddler2024_s = toc;
    preds.est_angle_saddler2024 = saddler_out.est_angle;
    preds.est_angle_expected_saddler2024 = saddler_out.est_angle_expected;
    preds.est_class_index_saddler2024 = saddler_out.est_class_index;
    preds.est_angle_saddler2024_per_model = saddler_out.est_angle_per_model;
    preds.est_angle_expected_saddler2024_per_model = saddler_out.est_angle_expected_per_model;
    preds.est_class_index_saddler2024_per_model = saddler_out.est_class_index_per_model;
    fprintf('saddler2024 elapsed: %.3f s\n', preds.time_saddler2024_s);
end

if cfg.run_wang2026
    disp("~~~ Evaluating wang2026 ~~~")
    tic
    wang_out = eval_wang2026(bin_signal_all_norm, fs, ...
        cfg.wang2026_pyFolder, cfg.wang2026_venvPython, cfg.wang2026_model_filename);
    preds.time_wang2026_s = toc;
    preds.est_angle_wang2026 = wang_out.est_angle;
    fprintf('wang2026 elapsed: %.3f s\n', preds.time_wang2026_s);
end

if cfg.run_vecchiotti2019
    disp("~~~ Evaluating vecchiotti2019 ~~~")
    vecchiotti_opts = default_vecchiotti2019_opts();
    vecchiotti_opts.listexp_data_id = listexp_data_id;
    vecchiotti_out = eval_vecchiotti2019(bin_signal_all_norm, fs, listexp_data, vecchiotti_opts);
    preds.est_angle_vecchiotti2019 = vecchiotti_out.est_angle;
    if ~isempty(vecchiotti_out.est_angle_raw)
        preds.est_angle_raw_vecchiotti2019 = vecchiotti_out.est_angle_raw;
    end
    if ~isempty(vecchiotti_out.est_angle_expected)
        preds.est_angle_expected_vecchiotti2019 = vecchiotti_out.est_angle_expected;
    end
    if ~isempty(vecchiotti_out.est_class_index)
        preds.est_class_index_vecchiotti2019 = vecchiotti_out.est_class_index;
    end
    if ~isempty(vecchiotti_out.vecchiotti_max_prob)
        preds.vecchiotti_max_prob = vecchiotti_out.vecchiotti_max_prob;
    end
    if ~isempty(vecchiotti_out.vecchiotti_prob_entropy)
        preds.vecchiotti_prob_entropy = vecchiotti_out.vecchiotti_prob_entropy;
    end
    preds.vecchiotti_error = vecchiotti_out.error;
    preds.vecchiotti_model_id = vecchiotti_out.model_id;
    preds.time_vecchiotti2019_s = vecchiotti_out.time_s;
    fprintf('vecchiotti2019 elapsed: %.3f s\n', preds.time_vecchiotti2019_s);
end
end

function template = template_for_enabled_model(templates, field_name, enabled)
template = [];
if enabled && isfield(templates, field_name)
    template = templates.(field_name);
end
end
