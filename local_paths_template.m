function lp = local_paths() %#ok<FNDEF> (rename this file to local_paths.m)
%LOCAL_PATHS Machine-specific locations of external dependencies.
%
%   SETUP: copy this file to local_paths.m (same folder) and edit the paths
%   below for your machine. local_paths.m is ignored by git, so your local
%   configuration never ends up in the repository.
%
%   Every field can also be overridden with an environment variable (name in
%   brackets), which takes precedence over the value written here. Leave a
%   field empty ("") if you do not use the corresponding model; it is only
%   checked when that model is (re)computed. Plotting from the cached model
%   outputs only needs amt_dir.
%
%   Fields
%       amt_dir             [AMT_DIR] Auditory Modelling Toolbox 1.6 root
%                           (folder containing amt_start.m). Required.
%       precsep_dir         [PRECSEP_DIR] PrecSep toolbox root (faller2004,
%                           prec_fallermerimaa). Empty = assumed on the path.
%       phaselocknet_dir    [PHASELOCKNET_DIR] phaselocknet_torch_CIAT_evaluation
%                           checkout (saddler2024; contains
%                           phaselocknet_evaluate_CIAT.py).
%       phaselocknet_python [PHASELOCKNET_PYTHON] Python interpreter of the
%                           phaselocknet virtual environment.
%       ei_yang_dir         [EI_YANG_DIR] ei_yang checkout (wang2026; contains
%                           cochleagram_func.py, ei_pattern_func.py, IEEE25_models/).
%       ei_yang_python      [EI_YANG_PYTHON] Python interpreter of the ei_yang
%                           virtual environment.
%       amt_python          [AMT_PYTHON] Python interpreter used by the AMT
%                           external environments (takanen2013 -> verhulst2012
%                           periphery; needs numpy/scipy). Defaults to
%                           phaselocknet_python, which satisfies this.
%       waveloc_dir         [WAVELOC_DIR] WaveLoc checkout on the host
%                           (vecchiotti2019; mounted into the Docker container).
%       docker_bin          [DOCKER_BIN] Absolute path to the docker CLI.
%                           Empty = auto-detect.

home = char(java.lang.System.getProperty('user.home'));

lp = struct();
lp.amt_dir             = env_or('AMT_DIR', fullfile(home, 'MATLAB', 'amtoolbox-1.6.0'));
lp.precsep_dir         = env_or('PRECSEP_DIR', fullfile(home, 'MATLAB', 'PrecSep_toolbox'));
lp.phaselocknet_dir    = env_or('PHASELOCKNET_DIR', fullfile(home, 'Repositories', 'phaselocknet_torch_CIAT_evaluation'));
lp.phaselocknet_python = env_or('PHASELOCKNET_PYTHON', fullfile(lp.phaselocknet_dir, '.venv', 'bin', 'python'));
lp.ei_yang_dir         = env_or('EI_YANG_DIR', fullfile(home, 'Repositories', 'ei_yang'));
lp.ei_yang_python      = env_or('EI_YANG_PYTHON', fullfile(lp.ei_yang_dir, '.venv', 'bin', 'python'));
lp.amt_python          = env_or('AMT_PYTHON', lp.phaselocknet_python);
lp.waveloc_dir         = env_or('WAVELOC_DIR', fullfile(home, 'Repositories', 'WaveLoc'));
lp.docker_bin          = env_or('DOCKER_BIN', '');
end

function value = env_or(env_name, default_value)
%ENV_OR Environment variable value if set, otherwise the default.
value = getenv(env_name);
if isempty(value)
    value = default_value;
end
value = char(value);
end
