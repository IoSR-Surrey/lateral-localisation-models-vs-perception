function setup_paths()
%SETUP_PATHS Add the repository code folders and external toolboxes to the path.
%
%   SETUP_PATHS() is called at the top of compare_models_to_perceptual_data.m
%   and build_model_output_r2_table.m. It
%     1. adds models/, data_analysis/, plotting/, stimuli/,
%        aux_data/frank2013 and aux_data/ramirez2024 to the MATLAB path;
%     2. reads local_paths.m (see local_paths_template.m) and starts the
%        Auditory Modelling Toolbox (amt_start) if it is not already running;
%     3. adds the PrecSep toolbox (faller2004) when configured.
%
%   The function is idempotent and cheap to call repeatedly (the main script
%   re-runs itself in 'combined_recompute' mode).

repo_root = fileparts(mfilename('fullpath'));

if exist('local_paths', 'file') ~= 2
    error('setup_paths:MissingLocalPaths', ...
        ['local_paths.m not found. Copy local_paths_template.m to local_paths.m ' ...
        'in %s and edit the paths for your machine (see README.md).'], repo_root);
end

code_dirs = {'models', 'data_analysis', 'plotting', 'stimuli', ...
    fullfile('aux_data', 'frank2013'), fullfile('aux_data', 'ramirez2024')};
for iDir = 1:numel(code_dirs)
    full_dir = fullfile(repo_root, code_dirs{iDir});
    if isfolder(full_dir)
        addpath(genpath_no_hidden(full_dir));
    end
end
addpath(repo_root);

lp = local_paths();

% Auditory Modelling Toolbox (also provides the SOFA API used for HRTFs).
if exist('amt_load', 'file') ~= 2
    amt_start_file = fullfile(lp.amt_dir, 'amt_start.m');
    if ~isfile(amt_start_file)
        error('setup_paths:MissingAMT', ...
            ['Auditory Modelling Toolbox not found (expected %s). ' ...
            'Set amt_dir in local_paths.m or the AMT_DIR environment variable.'], amt_start_file);
    end
    addpath(lp.amt_dir);
    amt_start();
end

% PrecSep toolbox (prec_fallermerimaa, used by faller2004).
if ~isempty(lp.precsep_dir) && exist('prec_fallermerimaa', 'file') ~= 2
    if isfolder(lp.precsep_dir)
        addpath(genpath_no_hidden(lp.precsep_dir));
    else
        warning('setup_paths:MissingPrecSep', ...
            ['PrecSep toolbox not found at %s; faller2004 cannot be recomputed. ' ...
            'Set precsep_dir in local_paths.m.'], lp.precsep_dir);
    end
end
end

function p = genpath_no_hidden(root_dir)
%GENPATH_NO_HIDDEN genpath without hidden/version-control/archive folders.
parts = strsplit(genpath(root_dir), pathsep);
keep = true(size(parts));
for iPart = 1:numel(parts)
    sub = parts{iPart};
    if isempty(sub)
        keep(iPart) = false;
        continue;
    end
    rel = strrep(sub, root_dir, '');
    segments = strsplit(rel, filesep);
    segments = segments(~cellfun(@isempty, segments));
    if any(startsWith(segments, '.')) || any(strcmp(segments, 'archive')) ...
            || any(strcmp(segments, '__pycache__'))
        keep(iPart) = false;
    end
end
p = strjoin(parts(keep), pathsep);
end
