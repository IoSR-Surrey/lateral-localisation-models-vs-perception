function runtime_s = get_saved_model_runtime_s(S, model_id)
%GET_SAVED_MODEL_RUNTIME_S Load batch runtime (seconds) for a model from saved output.
%
%   runtime_s = get_saved_model_runtime_s(S, model_id)
%
% S is a struct loaded from MC_MODEL_OUTPUT_*.mat. model_id is a char/string
% model identifier matching error_<model>.model_id. Returns NaN when timing
% was not saved or is non-finite.

runtime_s = NaN;
model_id = char(model_id);

time_field = '';
if strcmp(model_id, 'kurz2017') || strcmp(model_id, 'extended_re')
    time_field = 'time_kurz2017_s';
elseif strcmp(model_id, 'stitt2016') || strcmp(model_id, 'extended_rE_Stitt')
    time_field = 'time_stitt2016_s';
elseif strcmp(model_id, 'rE')
    time_field = 'time_rE_s';
elseif strcmp(model_id, 'saddler2024')
    time_field = 'time_saddler2024_s';
elseif strcmp(model_id, 'vecchiotti2019') || strcmp(model_id, 'waveloc')
    time_field = 'time_vecchiotti2019_s';
elseif strcmp(model_id, 'llado2025') || strcmp(model_id, 'desena2020')
    time_field = 'time_llado2025_s';
else
    time_field = ['time_' model_id '_s'];
end

if isfield(S, time_field)
    runtime_s = S.(time_field);
elseif (strcmp(model_id, 'llado2025') || strcmp(model_id, 'desena2020')) && isfield(S, 'time_desena2020_s')
    runtime_s = S.time_desena2020_s;
elseif strcmp(model_id, 'kurz2017') && isfield(S, 'time_extended_re_s')
    % Legacy combined extended-rE batch timer (kurz2017 only).
    runtime_s = S.time_extended_re_s;
end

if ~isscalar(runtime_s) || ~isfinite(runtime_s)
    runtime_s = NaN;
end
end
