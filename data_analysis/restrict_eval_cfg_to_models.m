function cfg = restrict_eval_cfg_to_models(cfg, model_ids)
%RESTRICT_EVAL_CFG_TO_MODELS Enable only the listed model ids in an eval cfg.
run_fields = { ...
    'run_lindemann1986', 'run_breebaart2001', 'run_faller2004', 'run_may2011', ...
    'run_dietz2011', 'run_takanen2013', 'run_llado2025', ...
    'run_extended_re', 'run_saddler2024', 'run_wang2026', 'run_vecchiotti2019'};
for iField = 1:numel(run_fields)
    cfg.(run_fields{iField}) = false;
end
model_ids = cellstr(model_ids);
for iModel = 1:numel(model_ids)
    mini = eval_cfg_for_model_only(cfg, model_ids{iModel});
    for iField = 1:numel(run_fields)
        if mini.(run_fields{iField})
            cfg.(run_fields{iField}) = true;
        end
    end
end
end

function mini_cfg = eval_cfg_for_model_only(base_cfg, model_id)
model_id = char(model_id);
run_fields = { ...
    'run_lindemann1986', 'run_breebaart2001', 'run_faller2004', 'run_may2011', ...
    'run_dietz2011', 'run_takanen2013', 'run_llado2025', ...
    'run_extended_re', 'run_saddler2024', 'run_wang2026', 'run_vecchiotti2019'};
for iField = 1:numel(run_fields)
    mini_cfg.(run_fields{iField}) = false;
end
mini_cfg = merge_struct_fields(mini_cfg, base_cfg);

switch model_id
    case 'lindemann1986'
        mini_cfg.run_lindemann1986 = true;
    case 'breebaart2001'
        mini_cfg.run_breebaart2001 = true;
    case 'faller2004'
        mini_cfg.run_faller2004 = true;
    case 'may2011'
        mini_cfg.run_may2011 = true;
    case 'dietz2011'
        mini_cfg.run_dietz2011 = true;
    case 'takanen2013'
        mini_cfg.run_takanen2013 = true;
    case {'llado2025', 'desena2020'}
        mini_cfg.run_llado2025 = true;
    case {'kurz2017', 'stitt2016', 'rE'}
        mini_cfg.run_extended_re = true;
    case 'saddler2024'
        mini_cfg.run_saddler2024 = true;
    case 'wang2026'
        mini_cfg.run_wang2026 = true;
    case 'vecchiotti2019'
        mini_cfg.run_vecchiotti2019 = true;
    otherwise
        error('restrict_eval_cfg_to_models:UnknownModel', 'Unknown model id: %s', model_id);
end
end

function out = merge_struct_fields(out, base)
base_fields = fieldnames(base);
for iField = 1:numel(base_fields)
    fname = base_fields{iField};
    if ~isfield(out, fname)
        out.(fname) = base.(fname);
    end
end
end
