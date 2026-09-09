function target_dir = download_stitt2016()
%DOWNLOAD_STITT2016 Install the Stitt et al. extended energy-vector code.
%
%   target_dir = DOWNLOAD_STITT2016() downloads the public implementation
%   from https://www.ssa-plugins.com/matlab-code/, extracts its four MATLAB
%   functions, and installs them in models/extended_re/stitt2016/.
%
%   The downloaded code is third-party software and is intentionally
%   excluded from this repository. Consult its source and included notices
%   for applicable terms. Re-running this function skips the download when
%   all four expected files are already installed.

this_dir = fileparts(mfilename('fullpath'));
target_dir = fullfile(this_dir, 'stitt2016');
required_files = { ...
    'ambiGains.m', ...
    'enervecExt.m', ...
    'ldspkGainListeningPosition.m', ...
    'precedenceWeights.m'};

if all(cellfun(@(name) isfile(fullfile(target_dir, name)), required_files))
    fprintf('Stitt et al. code is already installed in: %s\n', target_dir);
    return
end

url = ['https://www.ssa-plugins.com/wp-content/uploads/2017/12/' ...
    'ExtendedEnergyVector_public.zip'];
temp_dir = tempname;
mkdir(temp_dir);
cleanup_obj = onCleanup(@() remove_temp_dir(temp_dir));
zip_path = fullfile(temp_dir, 'ExtendedEnergyVector_public.zip');

fprintf('Downloading %s ...\n', url);
websave(zip_path, url);
unzip(zip_path, temp_dir);

source_dir = fullfile(temp_dir, 'ExtendedEnergyVector_public');
missing = required_files(~cellfun( ...
    @(name) isfile(fullfile(source_dir, name)), required_files));
if ~isempty(missing)
    error('download_stitt2016:UnexpectedArchive', ...
        'Downloaded archive is missing: %s', strjoin(missing, ', '));
end

if ~isfolder(target_dir)
    mkdir(target_dir);
end
for iFile = 1:numel(required_files)
    source_file = fullfile(source_dir, required_files{iFile});
    destination_file = fullfile(target_dir, required_files{iFile});
    copyfile(source_file, destination_file, 'f');
end

addpath(target_dir);
clear cleanup_obj
fprintf('Installed Stitt et al. code in: %s\n', target_dir);
end

function remove_temp_dir(temp_dir)
if isfolder(temp_dir)
    rmdir(temp_dir, 's');
end
end
