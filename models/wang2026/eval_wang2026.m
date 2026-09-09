function out = eval_wang2026(bin_signals, fs, pyFolder, venvPython, modelFilename, options)
%EVAL_WANG2026 Estimate lateral angle with the Wang (2026) ei_yang Keras model.
%
%   out = EVAL_WANG2026(bin_signals, fs, pyFolder, venvPython, modelFilename)
%   binds MATLAB to the ei_yang Python virtual environment, runs
%   wang2026_evaluate.py over all binaural signals, and returns lateral
%   angle estimates in degrees.
%
%   out = EVAL_WANG2026(..., FoldToLateral=false) returns full-circle
%   azimuth (after polarity negation) instead of front-back folding.
%
%   Inputs
%       bin_signals     Cell array of [nSamples x 2] binaural signals.
%       fs              Sampling rate in Hz.
%       pyFolder        Folder containing wang2026_evaluate.py.
%       venvPython      Path to the ei_yang venv Python interpreter.
%       modelFilename   Keras file under ei_yang/IEEE25_models/ (e.g. "P3.keras").
%
%   Name-Value Arguments
%       FoldToLateral   If true (default), fold to lateral angle in [-90, 90].
%                       If false, return full-circle azimuth after polarity fix.
%       EiYangRoot      Path to the ei_yang repository checkout (contains
%                       cochleagram_func.py, ei_pattern_func.py and
%                       IEEE25_models/). Default: local_paths().ei_yang_dir.
%
%   Output struct fields
%       est_angle       Predicted angle [1 x nSignals] (deg). With FoldToLateral
%                       true: [-90, 90], positive = left. With false: full azimuth
%                       after polarity negation (same sign convention as SOFA).
%       model_filename  Checkpoint filename used for this evaluation.
%
%   The ei_yang Keras model returns full azimuth via scaled_tanh (±180 deg)
%   with the opposite polarity to this codebase. Outputs are negated and then
%   (by default) front-back folded to lateral angle (same mapping as extended rE).

arguments
    bin_signals (1, :) cell
    fs (1, 1) {mustBePositive}
    pyFolder (1, 1) string
    venvPython (1, 1) string
    modelFilename (1, 1) string = "P3.keras"
    options.FoldToLateral (1, 1) logical = true
    options.EiYangRoot (1, 1) string = ""
end

eiYangRoot = options.EiYangRoot;
if strlength(eiYangRoot) == 0
    lp = local_paths();
    eiYangRoot = string(lp.ei_yang_dir);
end
if ~isfolder(eiYangRoot)
    error('eval_wang2026:MissingEiYang', ...
        'ei_yang repository not found at "%s". Set ei_yang_dir in local_paths.m.', eiYangRoot);
end

% Bind MATLAB to the ei_yang interpreter (session-scoped, out of process).
pe0 = pyenv;
if pe0.Status == "Loaded"
    terminate(pe0);
end
pe = pyenv("Version", venvPython, "ExecutionMode", "OutOfProcess");
assert(string(pe.Executable) == venvPython, ...
    "MATLAB did not bind to expected Python executable.");
py.os.chdir(py.str(pyFolder));

evaluate_script = "wang2026_evaluate.py";

% Pack signals into a [nSignals x nSamples x 2] array for the Python model.
bin_stim_array = permute(cat(3, bin_signals{:}), [3 1 2]);

pyResult = pyrunfile(fullfile(pyFolder, evaluate_script), "result", ...
    "binaural_signal", bin_stim_array, ...
    "signal_sr", int64(fs), ...
    "model_filename", char(modelFilename), ...
    "ei_yang_root", char(eiYangRoot));

% Negate (ei_yang polarity); optionally fold rear azimuths to lateral ±90 deg.
est_azimuth = -double(pyResult{"azimuth_deg"});
out = struct();
if options.FoldToLateral
    out.est_angle = fold_azimuth_to_lateral(est_azimuth);
else
    out.est_angle = est_azimuth;
end
out.model_filename = string(pyResult{"model_filename"});
end

function az_lat_deg = fold_azimuth_to_lateral(az_deg)
% Map azimuth to front-back folded lateral angle in [-90, 90] (positive = left).
% 0 -> 0, 45 -> 45, 90 -> 90, 135 -> 45, 180 -> 0,
% -45 -> -45, -135 -> -45, -180 -> 0.
az_deg = az_deg(:).';
az_sign = sign(az_deg);
az_sign(az_sign == 0) = 1;
az_abs = abs(az_deg);
az_norm = mod(az_abs, 360);
rear = az_norm > 180;
az_norm(rear) = 360 - az_norm(rear);
az_lat_deg = az_sign .* min(az_norm, 180 - az_norm);
end
