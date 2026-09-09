function hrtf_names = discover_hrtf_names_from_cache(model_output_dir, dataset_id)
%DISCOVER_HRTF_NAMES_FROM_CACHE Unique HRTF labels in per-model cache files.
safe_dataset = sanitize_model_output_token(dataset_id);
pattern = fullfile(model_output_dir, sprintf('MC_MODEL_OUTPUT_%s_*.mat', safe_dataset));
files = dir(pattern);
known_ids = all_model_output_model_ids();
geometry_label = geometry_model_ids('label');
hrtf_names = {};
prefix = sprintf('MC_MODEL_OUTPUT_%s_', safe_dataset);
for iFile = 1:numel(files)
    [~, basename, ~] = fileparts(files(iFile).name);
    if ~startsWith(basename, prefix)
        continue;
    end
    remainder = char(extractAfter(basename, prefix));
    for iId = 1:numel(known_ids)
        suffix = ['_' known_ids{iId}];
        if endsWith(remainder, suffix)
            sofa_name = char(extractBefore(remainder, suffix));
            if ~isempty(sofa_name) && ~strcmp(sofa_name, geometry_label)
                hrtf_names{end + 1} = sofa_name; %#ok<AGROW>
            end
            break;
        end
    end
end
hrtf_names = unique(hrtf_names, 'stable');
end
