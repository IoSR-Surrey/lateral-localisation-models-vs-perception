function cache_path = model_output_cache_path(model_output_dir, dataset_id, sofa_name, model_id)
%MODEL_OUTPUT_CACHE_PATH Canonical path for one per-model cache piece.
%
%   cache_path = MODEL_OUTPUT_CACHE_PATH(dir, dataset_id, sofa_name, model_id)
%
% Filenames: MC_MODEL_OUTPUT_<dataset>_<hrtf>_<model>.mat (stable, no timestamp).

safe_dataset = sanitize_model_output_token(dataset_id);
safe_sofa = sanitize_model_output_token(sofa_name);
safe_model = sanitize_model_output_token(model_id);
filename = sprintf('MC_MODEL_OUTPUT_%s_%s_%s.mat', safe_dataset, safe_sofa, safe_model);
cache_path = fullfile(model_output_dir, filename);
end
