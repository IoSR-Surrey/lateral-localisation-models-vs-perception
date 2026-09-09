function est_pred = get_saved_model_predictions(S, model_id)
%GET_SAVED_MODEL_PREDICTIONS Load est_angle vector for a model from saved output.
%
%   est_pred = get_saved_model_predictions(S, model_id)
%
% S is a struct loaded from MC_MODEL_OUTPUT_*.mat. model_id is a char/string
% model identifier matching error_<model>.model_id.

est_pred = [];
model_id = char(model_id);

if strcmp(model_id, 'saddler2024')
    if isfield(S, 'est_angle_expected_saddler2024')
        est_pred = S.est_angle_expected_saddler2024(:);
    end
elseif strcmp(model_id, 'vecchiotti2019') || strcmp(model_id, 'waveloc')
    if isfield(S, 'est_angle_vecchiotti2019')
        est_pred = S.est_angle_vecchiotti2019(:);
    elseif isfield(S, 'est_angle_waveloc')
        est_pred = S.est_angle_waveloc(:);
    end
elseif strcmp(model_id, 'kurz2017') || strcmp(model_id, 'extended_re')
    % extended_re is the legacy model id from pre-rename saved outputs.
    if isfield(S, 'est_angle_kurz2017')
        est_pred = S.est_angle_kurz2017(:);
    elseif isfield(S, 'est_angle_extended_re')
        est_pred = S.est_angle_extended_re(:);
    end
elseif strcmp(model_id, 'llado2025') || strcmp(model_id, 'desena2020')
    % desena2020 is the legacy model id from pre-rename saved outputs.
    if isfield(S, 'est_angle_llado2025')
        est_pred = S.est_angle_llado2025(:);
    elseif isfield(S, 'est_angle_desena2020')
        est_pred = S.est_angle_desena2020(:);
    end
elseif strcmp(model_id, 'stitt2016') || strcmp(model_id, 'extended_rE_Stitt')
    if isfield(S, 'est_angle_stitt2016')
        est_pred = S.est_angle_stitt2016(:);
    elseif isfield(S, 'est_angle_extended_rE_Stitt')
        est_pred = S.est_angle_extended_rE_Stitt(:);
    end
else
    pred_varname = ['est_angle_' model_id];
    if isfield(S, pred_varname)
        est_pred = S.(pred_varname)(:);
    end
end

if isempty(est_pred)
    error('get_saved_model_predictions:Missing', ...
        'Missing saved predicted angles for model: %s', model_id);
end
end
