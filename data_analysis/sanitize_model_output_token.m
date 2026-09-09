function safe_token = sanitize_model_output_token(token)
%SANITIZE_MODEL_OUTPUT_TOKEN Safe filename token for model-output cache paths.
safe_token = regexprep(char(token), '[^A-Za-z0-9_-]', '_');
end
