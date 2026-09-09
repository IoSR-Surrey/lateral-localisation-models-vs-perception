function est_sem = get_saved_model_sem(S, model_id)
%GET_SAVED_MODEL_SEM Load per-stimulus SEM vector for a model from saved output.
model_id = char(model_id);

if strcmp(model_id, 'saddler2024')
    sem_varname = 'est_angle_expected_saddler2024_sem';
elseif strcmp(model_id, 'vecchiotti2019') || strcmp(model_id, 'waveloc')
    sem_varname = 'est_angle_vecchiotti2019_sem';
elseif strcmp(model_id, 'kurz2017') || strcmp(model_id, 'extended_re')
    sem_varname = 'est_angle_kurz2017_sem';
elseif strcmp(model_id, 'llado2025') || strcmp(model_id, 'desena2020')
    sem_varname = 'est_angle_llado2025_sem';
elseif strcmp(model_id, 'stitt2016') || strcmp(model_id, 'extended_rE_Stitt')
    sem_varname = 'est_angle_stitt2016_sem';
elseif strcmp(model_id, 'rE')
    sem_varname = 'est_angle_rE_sem';
else
    sem_varname = ['est_angle_' model_id '_sem'];
end

est_sem = [];
if isfield(S, sem_varname)
    est_sem = S.(sem_varname)(:);
elseif (strcmp(model_id, 'llado2025') || strcmp(model_id, 'desena2020')) && isfield(S, 'est_angle_desena2020_sem')
    est_sem = S.est_angle_desena2020_sem(:);
end
end
