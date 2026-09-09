function save_model_output_piece(cache_path, piece)
%SAVE_MODEL_OUTPUT_PIECE Save one per-model cache piece to disk.
cache_dir = fileparts(cache_path);
if ~isempty(cache_dir) && ~isfolder(cache_dir)
    mkdir(cache_dir);
end
save(cache_path, '-struct', 'piece', '-v7');
end
