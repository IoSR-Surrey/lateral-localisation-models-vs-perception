function out = eval_extended_re(listexp_data_id, listexp_data, re_cfg, nSignals)
%EVAL_EXTENDED_RE Estimate lateral angle with the extended energy-vector models.
%
%   out = EVAL_EXTENDED_RE(listexp_data_id, listexp_data, re_cfg, nSignals)
%   computes three loudspeaker-geometry energy-vector estimates per trial:
%       out.kurz2017    Kurz et al. (2017) extended rE model.
%       out.stitt2016   Stitt et al. (2016) extended rE via enervecExt.
%       out.rE          Classic rE (Stitt model with alpha = 1).
%   Each is a [1 x nSignals] vector of angles (deg) after the dataset sign
%   correction in re_cfg.sign_correction.
%
%   The per-trial loudspeaker metadata is computed once and reused across the
%   three models.
%
%   Inputs
%       listexp_data_id  Dataset identifier (string/char).
%       listexp_data     Loaded perceptual-data struct.
%       re_cfg           Extended rE configuration struct (see caller).
%       nSignals         Number of trials/signals.

re_cfg_classic = re_cfg;
re_cfg_classic.alpha = 1; % classic rE uses alpha = 1

kurz2017 = nan(1, nSignals);
stitt2016 = nan(1, nSignals);
rE = nan(1, nSignals);
time_kurz2017_s = 0;
time_stitt2016_s = 0;
time_rE_s = 0;

for isig = 1:nSignals
    meta = re_get_trial_lsp_metadata(listexp_data_id, listexp_data, isig, re_cfg);

    t0 = tic;
    est_kurz = re_extended_energy_vector_kurz2017(meta, re_cfg);
    time_kurz2017_s = time_kurz2017_s + toc(t0);
    kurz2017(isig) = re_cfg.sign_correction * est_kurz;

    t0 = tic;
    est_stitt = re_extended_energy_vector_stitt2016(meta, re_cfg, listexp_data_id);
    time_stitt2016_s = time_stitt2016_s + toc(t0);
    stitt2016(isig) = re_cfg.sign_correction * est_stitt;

    t0 = tic;
    est_classic = re_extended_energy_vector_stitt2016(meta, re_cfg_classic, listexp_data_id);
    time_rE_s = time_rE_s + toc(t0);
    rE(isig) = re_cfg.sign_correction * est_classic;
end

out = struct( ...
    'kurz2017', kurz2017, ...
    'stitt2016', stitt2016, ...
    'rE', rE, ...
    'time_kurz2017_s', time_kurz2017_s, ...
    'time_stitt2016_s', time_stitt2016_s, ...
    'time_rE_s', time_rE_s);
end
