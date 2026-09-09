function canonical_id = canonical_model_id(model_id)
%CANONICAL_MODEL_ID Map legacy model ids to the current canonical id.
canonical_id = char(string(model_id));

legacy_to_canonical = {
    'desena2020', 'llado2025'
    'extended_re', 'kurz2017'
    'extended_rE_Stitt', 'stitt2016'
    'waveloc', 'vecchiotti2019'};

for ridx = 1:size(legacy_to_canonical, 1)
    if strcmp(canonical_id, legacy_to_canonical{ridx, 1})
        canonical_id = legacy_to_canonical{ridx, 2};
        return;
    end
end
end
