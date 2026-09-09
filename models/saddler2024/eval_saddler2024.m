function out = eval_saddler2024(bin_signals, fs, pyFolder, venvPython)
%EVAL_SADDLER2024 Estimate lateral angle with the Saddler (2024) phaselocknet model.
%
%   out = EVAL_SADDLER2024(bin_signals, fs, pyFolder, venvPython) binds MATLAB
%   to the phaselocknet Python virtual environment, runs the CIAT evaluation
%   script over all binaural signals, and returns the ensemble and per-model
%   azimuth estimates.
%
%   Inputs
%       bin_signals  Cell array of [nSamples x 2] binaural signals.
%       fs           Sampling rate in Hz.
%       pyFolder     Folder containing phaselocknet_evaluate_CIAT.py.
%       venvPython   Path to the phaselocknet venv Python interpreter.
%
%   Output struct fields
%       est_angle             Ensemble argmax azimuth [1 x nSignals] (deg).
%       est_angle_expected    Ensemble expected azimuth [1 x nSignals] (deg).
%       est_class_index       Ensemble predicted class index [1 x nSignals].
%       est_angle_per_model            Per-model argmax azimuths (cell).
%       est_angle_expected_per_model   Per-model expected azimuths (cell).
%       est_class_index_per_model      Per-model class indices (cell).

% Bind MATLAB to the phaselocknet interpreter (session-scoped, out of process).
pe0 = pyenv;
if pe0.Status == "Loaded"
    terminate(pe0);
end
pe = pyenv("Version", venvPython, "ExecutionMode", "OutOfProcess");
assert(string(pe.Executable) == venvPython, ...
    "MATLAB did not bind to expected Python executable.");
py.os.chdir(py.str(pyFolder));

evaluate_script = "phaselocknet_evaluate_CIAT.py";
% arch_indices = 1:3;
arch_indices = 1;

% Pack signals into a [nSignals x nSamples x 2] array for the Python model.
% NB: the model output depends on input level.
bin_stim_array = permute(cat(3, bin_signals{:}), [3 1 2]);

pyResult = pyrunfile(fullfile(pyFolder, evaluate_script), "result", ...
    "binaural_signal", bin_stim_array, ...
    "signal_sr", int64(fs), ...
    "arch_indices", int64(arch_indices), ...
    "eval_batch_size", int64(3));

out = struct();
out.est_angle = double(pyResult{"argmax_azimuth_deg"});
out.est_angle_expected = double(pyResult{"expected_azimuth_deg"});
out.est_class_index = double(pyResult{"predicted_class_index"});

pyPerModel = pyResult{"per_model"};
est_angle_per_model = cell(pyPerModel{"argmax_azimuth_deg"});
est_angle_expected_per_model = cell(pyPerModel{"expected_azimuth_deg"});
est_class_index_per_model = cell(pyPerModel{"predicted_class_index"});
for aidx = 1:numel(arch_indices)
    est_angle_per_model{aidx} = double(est_angle_per_model{aidx});
    est_angle_expected_per_model{aidx} = double(est_angle_expected_per_model{aidx});
    est_class_index_per_model{aidx} = double(est_class_index_per_model{aidx});
end
out.est_angle_per_model = est_angle_per_model;
out.est_angle_expected_per_model = est_angle_expected_per_model;
out.est_class_index_per_model = est_class_index_per_model;
end
