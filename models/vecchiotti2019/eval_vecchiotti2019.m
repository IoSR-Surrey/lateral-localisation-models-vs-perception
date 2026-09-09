function result = eval_vecchiotti2019(bin_signal_all_norm, fs, listexp_data, opts)
%EVAL_VECCHIOTTI2019 Run Vecchiotti et al. (2019) WaveLoc model inference.
%
%   result = EVAL_VECCHIOTTI2019(bin_signal_all_norm, fs, listexp_data, opts)
%
%   Inputs
%       bin_signal_all_norm : cell array of [nSamples x 2] binaural stimuli
%       fs                  : sample rate of the signals (Hz)
%       listexp_data        : listening experiment struct used to compute
%                             error metrics via FUNC_ERRORMETRICS
%       opts                : configuration struct returned by
%                             DEFAULT_VECCHIOTTI2019_OPTS (or a struct with
%                             the same fields). May include listexp_data_id
%                             to resolve sign_correction automatically.
%
%   Output
%       result : struct with fields
%           est_angle               1xN argmax azimuth in degrees, after
%                                   applying opts.sign_correction
%           est_angle_raw           1xN raw argmax azimuth before sign fix
%           est_angle_expected      1xN expected azimuth in degrees (or [])
%           est_class_index         1xN argmax class index (or [])
%           vecchiotti_max_prob     1xN peak softmax probability per trial
%           vecchiotti_prob_entropy 1xN softmax entropy per trial
%           error                   error struct from FUNC_ERRORMETRICS
%           model_id                'vecchiotti2019'
%           time_s                  elapsed time in seconds
%
%   Inference uses the WaveLoc implementation inside a Docker container; see
%   DEFAULT_VECCHIOTTI2019_OPTS for configuration fields.

if nargin < 4 || isempty(opts)
    opts = default_vecchiotti2019_opts();
end
opts = fill_vecchiotti2019_opts(opts);

t_start = tic;

waveloc_input_host = fullfile(tempdir, ...
    "waveloc_input_" + char(java.util.UUID.randomUUID) + ".mat");
waveloc_output_host = fullfile(tempdir, ...
    "waveloc_output_" + char(java.util.UUID.randomUUID) + ".json");

bin_stim_array = permute(cat(3, bin_signal_all_norm{:}), [3 1 2]); % [nSignals x nSamples x 2]
binaural_signal = single(bin_stim_array); %#ok<NASGU>
signal_sr = int64(fs); %#ok<NASGU>
save(waveloc_input_host, "binaural_signal", "signal_sr");

run_waveloc_in_docker( ...
    char(opts.repo_host), ...
    char(opts.container_name), ...
    char(opts.docker_image), ...
    char(opts.container_workdir), ...
    char(opts.bridge_script_host), ...
    char(opts.bridge_script_container), ...
    char(opts.model_dir_container), ...
    char(opts.input_container), ...
    char(opts.output_container), ...
    char(waveloc_input_host), ...
    char(waveloc_output_host), ...
    char(opts.docker_bin), ...
    opts.chunk_size, ...
    opts.energy_threshold_db);

if ~isfile(waveloc_output_host)
    error("WaveLoc output file was not created: %s", waveloc_output_host);
end

waveloc_result = jsondecode(fileread(waveloc_output_host));
if ~isfield(waveloc_result, 'argmax_azimuth_deg')
    error("WaveLoc output missing field 'argmax_azimuth_deg'.");
end

est_angle_raw = double(waveloc_result.argmax_azimuth_deg(:))';
sgn = opts.sign_correction;
est_angle = sgn * est_angle_raw;

est_class_index = [];
if isfield(waveloc_result, 'predicted_class_index')
    est_class_index = double(waveloc_result.predicted_class_index(:))';
end
est_angle_expected = [];
if isfield(waveloc_result, 'expected_azimuth_deg')
    est_angle_expected = sgn * double(waveloc_result.expected_azimuth_deg(:))';
end

vecchiotti_max_prob = [];
vecchiotti_prob_entropy = [];
if isfield(waveloc_result, 'max_prob')
    vecchiotti_max_prob = double(waveloc_result.max_prob(:))';
end
if isfield(waveloc_result, 'prob_entropy')
    vecchiotti_prob_entropy = double(waveloc_result.prob_entropy(:))';
end

if numel(est_angle) ~= numel(listexp_data.avgResponseVector)
    error("WaveLoc output length mismatch: pred=%d, resp=%d", ...
        numel(est_angle), numel(listexp_data.avgResponseVector));
end

warn_if_vecchiotti_degenerate(est_class_index, vecchiotti_max_prob, ...
    vecchiotti_prob_entropy, waveloc_result);

result = struct();
result.est_angle = est_angle;
result.est_angle_raw = est_angle_raw;
result.est_angle_expected = est_angle_expected;
result.est_class_index = est_class_index;
result.vecchiotti_max_prob = vecchiotti_max_prob;
result.vecchiotti_prob_entropy = vecchiotti_prob_entropy;
result.error = func_errormetrics(est_angle, listexp_data);
result.model_id = 'vecchiotti2019';
result.time_s = toc(t_start);
end


function opts = fill_vecchiotti2019_opts(opts)
defaults = default_vecchiotti2019_opts();
default_fields = fieldnames(defaults);
for iField = 1:numel(default_fields)
    field_name = default_fields{iField};
    if ~isfield(opts, field_name) || isempty(opts.(field_name))
        opts.(field_name) = defaults.(field_name);
    end
end

if isempty(opts.sign_correction)
    if ~isempty(opts.listexp_data_id)
        opts.sign_correction = waveloc_get_sign_correction(opts.listexp_data_id);
    else
        opts.sign_correction = -1;
    end
end
end


function warn_if_vecchiotti_degenerate(est_class_index, max_prob, entropy, waveloc_result)
if isempty(est_class_index)
    return
end

if numel(unique(est_class_index)) == 1
    warning("vecchiotti2019:WaveLocDegenerate", ...
        "All WaveLoc class indices are %d (raw azimuth %.0f deg).", ...
        est_class_index(1), (est_class_index(1) - 18) * 5);
end

boundary_mask = est_class_index == 0 | est_class_index == 36;
if all(boundary_mask)
    warning("vecchiotti2019:WaveLocBoundary", ...
        "All WaveLoc predictions are boundary classes (0 or 36).");
end

if isempty(max_prob) || isempty(entropy)
    return
end

uniform_entropy = log(37);
if isfield(waveloc_result, 'uniform_entropy')
    uniform_entropy = double(waveloc_result.uniform_entropy);
end

near_uniform = entropy >= 0.95 * uniform_entropy & max_prob <= (1 / 37 + 0.02);
if all(near_uniform)
    warning("vecchiotti2019:WaveLocUniform", ...
        "WaveLoc softmax is near-uniform on all trials (entropy ~ %.2f).", ...
        mean(entropy));
end
end


function run_waveloc_in_docker( ...
    waveloc_repo_host, container_name, docker_image, container_workdir, ...
    bridge_script_host, bridge_script_container, model_dir_container, input_container, output_container, ...
    input_host, output_host, docker_bin, chunk_size, energy_threshold_db)

docker_bin = locate_docker_binary(docker_bin);

ensure_waveloc_container_running( ...
    docker_bin, waveloc_repo_host, container_name, docker_image, container_workdir);

if ~isfile(bridge_script_host)
    error("WaveLoc bridge script not found on host: %s", bridge_script_host);
end
if system(sprintf('"%s" cp "%s" "%s:%s"', docker_bin, bridge_script_host, container_name, bridge_script_container)) ~= 0
    error("Failed to copy WaveLoc bridge script into container.");
end

check_script_cmd = sprintf('"%s" exec "%s" test -f "%s"', docker_bin, container_name, bridge_script_container);
if system(check_script_cmd) ~= 0
    error("WaveLoc bridge script not found in container: %s", bridge_script_container);
end

check_model_cmd = sprintf('"%s" exec "%s" test -f "%s/config.cfg"', docker_bin, container_name, model_dir_container);
if system(check_model_cmd) ~= 0
    error("WaveLoc model config not found in container model_dir: %s", model_dir_container);
end

if system(sprintf('"%s" cp "%s" "%s:%s"', docker_bin, input_host, container_name, input_container)) ~= 0
    error("Failed to copy WaveLoc input file into container.");
end

system(sprintf('"%s" exec "%s" rm -f "%s"', docker_bin, container_name, output_container)); %#ok<NASGU>

infer_cmd = sprintf([ ...
    '"%s" exec -w "%s" -e PYTHONPATH="%s" "%s" python "%s" ' ...
    '--input_mat "%s" --output_json "%s" --model_dir "%s" ' ...
    '--chunk_size %d --energy_threshold_db %.6g'], ...
    docker_bin, container_workdir, container_workdir, container_name, ...
    bridge_script_container, input_container, output_container, model_dir_container, ...
    chunk_size, energy_threshold_db);
infer_status = system(infer_cmd);
if infer_status ~= 0
    error("WaveLoc inference failed inside container (status=%d).", infer_status);
end

if system(sprintf('"%s" cp "%s:%s" "%s"', docker_bin, container_name, output_container, output_host)) ~= 0
    error("Failed to copy WaveLoc output file from container.");
end
end


function ensure_waveloc_container_running(docker_bin, waveloc_repo_host, container_name, docker_image, container_workdir)
created_container = false;
is_running_cmd = sprintf( ...
    '"%s" ps --filter "name=^/%s$" --format "{{.Names}}"', docker_bin, container_name);
[status_running, running_name] = system(is_running_cmd);
if status_running == 0 && strcmp(strtrim(running_name), container_name)
    warn_if_waveloc_container_layout_mismatch(docker_bin, container_name, waveloc_repo_host, container_workdir);
    ensure_waveloc_python_deps(docker_bin, container_name, container_workdir);
    return
end

exists_cmd = sprintf( ...
    '"%s" ps -a --filter "name=^/%s$" --format "{{.Names}}"', docker_bin, container_name);
[status_exists, existing_name] = system(exists_cmd);
if status_exists == 0 && strcmp(strtrim(existing_name), container_name)
    start_cmd = sprintf('"%s" start "%s" > /dev/null', docker_bin, container_name);
    if system(start_cmd) ~= 0
        error("WaveLoc container exists but failed to start: %s", container_name);
    end
    warn_if_waveloc_container_layout_mismatch(docker_bin, container_name, waveloc_repo_host, container_workdir);
    ensure_waveloc_python_deps(docker_bin, container_name, container_workdir);
    return
end

if ~isfolder(waveloc_repo_host)
    error("WaveLoc host repository path not found: %s", waveloc_repo_host);
end

create_cmd = sprintf([ ...
    '"%s" run --platform linux/amd64 -d --name "%s" ' ...
    '-v "%s":"%s" -w "%s" "%s" sleep infinity'], ...
    docker_bin, container_name, waveloc_repo_host, container_workdir, container_workdir, docker_image);
if system(create_cmd) ~= 0
    error("Failed to create/start WaveLoc container: %s", container_name);
end
created_container = true;
ensure_waveloc_python_deps(docker_bin, container_name, container_workdir);

if created_container
    run_waveloc_import_sanity_check(docker_bin, container_name, container_workdir);
end
end


function ensure_waveloc_python_deps(docker_bin, container_name, container_workdir)
marker_path = sprintf("%s/.waveloc_deps_installed", container_workdir);
check_marker_cmd = sprintf('"%s" exec "%s" test -f "%s"', docker_bin, container_name, marker_path);
if system(check_marker_cmd) == 0
    return
end

install_cmd = sprintf([ ...
    '"%s" exec -w "%s" "%s" bash -lc ''apt-get update -qq && ' ...
    'apt-get install -y -qq pkg-config libhdf5-dev libnetcdf-dev gcc g++ gfortran && ' ...
    'pip install --no-cache-dir -r requirements.txt && ' ...
    'touch "%s"'''], ...
    docker_bin, container_workdir, container_name, marker_path);
install_status = system(install_cmd);
if install_status ~= 0
    error("Failed to install WaveLoc Python dependencies in container %s.", container_name);
end
end


function run_waveloc_import_sanity_check(docker_bin, container_name, container_workdir)
check_cmd = sprintf([ ...
    '"%s" exec -w "%s" -e PYTHONPATH="%s" "%s" python -c ''import tensorflow; import gammatone; from WaveLoc import WaveLoc'''], ...
    docker_bin, container_workdir, container_workdir, container_name);
if system(check_cmd) ~= 0
    error("WaveLoc container sanity check failed (TensorFlow / gammatone / WaveLoc import).");
end
end


function warn_if_waveloc_container_layout_mismatch(docker_bin, container_name, waveloc_repo_host, container_workdir)
% Two simple inspect calls. Avoids using `eq` with quoted string literals
% in the Go template format, which is brittle across docker versions.
[wd_status, wd_out] = system(sprintf( ...
    '"%s" inspect "%s" --format "{{.Config.WorkingDir}}"', ...
    docker_bin, container_name));
[m_status, m_out] = system(sprintf( ...
    '"%s" inspect "%s" --format "{{range .Mounts}}{{.Source}}=>{{.Destination}}|{{end}}"', ...
    docker_bin, container_name));
if wd_status ~= 0 || m_status ~= 0
    warning("Could not inspect WaveLoc container layout for %s.", container_name);
    return
end

actual_workdir = strtrim(wd_out);
mounts_raw = strtrim(m_out);
mount_entries = strsplit(mounts_raw, '|');
actual_mount_dest = '';
for k = 1:numel(mount_entries)
    entry = strtrim(mount_entries{k});
    if isempty(entry)
        continue
    end
    pair = strsplit(entry, '=>');
    if numel(pair) ~= 2
        continue
    end
    if strcmp(strtrim(pair{1}), waveloc_repo_host)
        actual_mount_dest = strtrim(pair{2});
        break
    end
end

if ~strcmp(actual_workdir, container_workdir) || ~strcmp(actual_mount_dest, container_workdir)
    warning([ ...
        "WaveLoc container layout mismatch for %s.\n" ...
        "Expected WorkingDir and mount destination: %s\n" ...
        "Actual WorkingDir: %s\n" ...
        "Actual mount destination for host path %s: %s\n" ...
        "If this is unexpected, recreate the container with the configured paths."], ...
        container_name, container_workdir, actual_workdir, waveloc_repo_host, actual_mount_dest);
end
end


function docker_bin = locate_docker_binary(docker_bin)
% Resolve an absolute path to the docker CLI. MATLAB on macOS launched
% from Finder/Dock often has a stripped PATH that does not include
% Docker Desktop's CLI even though it is available from a normal
% Terminal. We try:
%   1. user-provided absolute path
%   2. login shell lookup via `command -v docker`
%   3. common macOS install locations
if ~isempty(docker_bin) && isfile(docker_bin)
    return
end

shell_lookup_cmds = { ...
    '/bin/zsh -lc ''command -v docker''', ...
    '/bin/bash -lc ''command -v docker''' ...
    };
for k = 1:numel(shell_lookup_cmds)
    [status, out] = system(shell_lookup_cmds{k});
    candidate = strtrim(out);
    if status == 0 && ~isempty(candidate) && isfile(candidate)
        docker_bin = candidate;
        return
    end
end

candidate_paths = { ...
    '/usr/local/bin/docker', ...
    '/opt/homebrew/bin/docker', ...
    '/Applications/Docker.app/Contents/Resources/bin/docker' ...
    };
for k = 1:numel(candidate_paths)
    if isfile(candidate_paths{k})
        docker_bin = candidate_paths{k};
        return
    end
end

error([ ...
    "Could not locate the docker CLI from MATLAB.\n" ...
    "MATLAB on macOS often does not inherit the same PATH as Terminal.\n" ...
    "Set 'opts.docker_bin' in DEFAULT_VECCHIOTTI2019_OPTS to the absolute path of\n" ...
    "the docker binary, e.g. '/usr/local/bin/docker' or\n" ...
    "'/Applications/Docker.app/Contents/Resources/bin/docker'."]);
end
