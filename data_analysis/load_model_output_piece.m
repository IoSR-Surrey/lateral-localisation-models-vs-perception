function piece = load_model_output_piece(cache_path)
%LOAD_MODEL_OUTPUT_PIECE Load one per-model cache piece from disk.
if ~isfile(cache_path)
    error('load_model_output_piece:MissingFile', ...
        'Model output cache not found: %s', cache_path);
end
piece = load(cache_path);
end
