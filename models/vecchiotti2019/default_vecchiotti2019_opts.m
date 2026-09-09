function opts = default_vecchiotti2019_opts()
%DEFAULT_VECCHIOTTI2019_OPTS Default Vecchiotti (2019) / WaveLoc Docker config.
%
%   opts = DEFAULT_VECCHIOTTI2019_OPTS() returns a struct with the configuration
%   used by EVAL_VECCHIOTTI2019. Machine-specific locations (repo_host,
%   docker_bin) are taken from local_paths.m (see local_paths_template.m).
%
%   Fields
%       repo_host                Host path to the WaveLoc repository
%                                (local_paths().waveloc_dir).
%       model_dir_container      Path to the WaveLoc model dir inside the
%                                container (must contain config.cfg).
%       bridge_script_host       Host path to the Python bridge script
%                                (waveloc_inference_from_matlab.py).
%       bridge_script_container  Bridge script path inside the container.
%       container_name           Docker container name (must match the
%                                devcontainer name when using one).
%       docker_image             Image used to create the container if it
%                                does not yet exist.
%       container_workdir        Working directory inside the container.
%       input_container          Path inside the container for the input
%                                .mat file written by MATLAB.
%       output_container         Path inside the container for the output
%                                .json file written by Python.
%       docker_bin               Absolute path to docker CLI
%                                (local_paths().docker_bin). Empty =
%                                auto-detect (handles the common macOS
%                                case where MATLAB's PATH does not include
%                                Docker Desktop's CLI even when it is on
%                                PATH from a regular terminal).
%       listexp_data_id          Dataset id used to resolve sign_correction
%                                when opts.sign_correction is empty.
%       sign_correction          Scalar applied to model azimuth outputs to
%                                match the sign convention of the
%                                perceptual datasets used here.
%       chunk_size               WaveLoc chunk length in frames (paper: 25).
%       energy_threshold_db      Drop frames below this level (dB rel. peak).
%
%   Use the IoSR-Surrey WaveLoc fork:
%   https://github.com/IoSR-Surrey/WaveLoc
%   Trained models are not included in the repository and can currently be
%   requested from the authors. Place the Room_C model files under
%   models/mct/Room_C on the host before running.

lp = local_paths();

opts = struct();
opts.repo_host = string(lp.waveloc_dir);
opts.model_dir_container = "/workspaces/WaveLoc/models/mct/Room_C";

this_dir = fileparts(mfilename('fullpath'));
opts.bridge_script_host = fullfile(this_dir, "waveloc_inference_from_matlab.py");
opts.bridge_script_container = "/tmp/waveloc_inference_from_matlab.py";

opts.container_name = "waveloc_inference";
opts.docker_image = "python:3.7-bullseye";
opts.container_workdir = "/workspaces/WaveLoc";
opts.input_container = "/tmp/waveloc_input.mat";
opts.output_container = "/tmp/waveloc_output.json";
opts.docker_bin = string(lp.docker_bin);
opts.listexp_data_id = "";
opts.sign_correction = [];
opts.chunk_size = 25;
opts.energy_threshold_db = -40;
end
