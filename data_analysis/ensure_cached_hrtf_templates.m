function templates = ensure_cached_hrtf_templates(obj_work, fs, sofa_name, cfg)
%ENSURE_CACHED_HRTF_TEMPLATES Load cached HRTF templates, building any that are missing.
%
%   templates = ENSURE_CACHED_HRTF_TEMPLATES(obj_work, fs, sofa_name, cfg)
%   loads templates/MC_TEMPLATES_<sofa_name>[_<fs>Hz].mat when present, builds only
%   templates required by cfg that are absent from the cache, and merges new templates
%   back into the same .mat file.

fs_native = obj_work.Data.SamplingRate;
template_fs_suffix = '';
if fs ~= fs_native
    template_fs_suffix = sprintf('_%dHz', fs);
end
templates_fn = fullfile('templates', ['MC_TEMPLATES_' sofa_name template_fs_suffix '.mat']);

specs = hrtf_template_field_specs(cfg);
cached = struct();
if isfile(templates_fn)
    cached = load(templates_fn);
end

missing_model_ids = {};
for iSpec = 1:size(specs, 1)
    field_name = specs{iSpec, 2};
    if ~isfield(cached, field_name) || isempty(cached.(field_name))
        missing_model_ids{end + 1} = specs{iSpec, 1}; %#ok<AGROW>
    end
end

if ~isempty(missing_model_ids)
    use_parallel = true;
    if isfield(cfg, 'use_parallel') && ~isempty(cfg.use_parallel)
        use_parallel = logical(cfg.use_parallel);
    end
    maxWorkers = Inf;
    if ~use_parallel
        maxWorkers = 0;
    end

    disp('~~~ BUILDING MISSING TEMPLATES ~~~')
    built_templates = cell(1, numel(missing_model_ids));
    parfor (midx = 1:numel(missing_model_ids), maxWorkers)
        model_id = missing_model_ids{midx};
        built_templates{midx} = build_hrtf_template(model_id, obj_work, fs);
        disp([' - ' model_id ' template built'])
    end

    for midx = 1:numel(missing_model_ids)
        model_id = missing_model_ids{midx};
        field_name = specs{strcmp(specs(:, 1), model_id), 2};
        cached.(field_name) = built_templates{midx};
    end

    if ~isfolder('templates')
        mkdir templates
    end
    save(templates_fn, '-struct', 'cached');
    disp(['Templates saved to: ' templates_fn])
end

templates = struct();
for iSpec = 1:size(specs, 1)
    field_name = specs{iSpec, 2};
    if isfield(cached, field_name)
        templates.(field_name) = cached.(field_name);
    else
        templates.(field_name) = [];
    end
end
end

function specs = hrtf_template_field_specs(cfg)
% Each row: {model_id, cache_field_name}.
candidate_specs = { ...
    'lindemann1986', 'template_lindemann1986', cfg.run_lindemann1986; ...
    'breebaart2001', 'template_breebaart2001', cfg.run_breebaart2001; ...
    'faller2004', 'template_faller2004', cfg.run_faller2004; ...
    'dietz2011', 'template_dietz2011', cfg.run_dietz2011; ...
    'llado2025', 'template_llado2025', cfg.run_llado2025};
specs = candidate_specs(cell2mat(candidate_specs(:, 3)), 1:2);
end

function template = build_hrtf_template(model_id, obj_work, fs)
switch model_id
    case 'llado2025'
        template = desena2020_buildtemplate(obj_work);
    otherwise
        template = itd2angle_lookuptable_pl(obj_work, fs, model_id);
end
end
