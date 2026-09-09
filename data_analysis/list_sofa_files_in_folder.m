function [sofa_paths, sofa_names] = list_sofa_files_in_folder(sofa_dir)
%LIST_SOFA_FILES_IN_FOLDER List .sofa files in a directory (non-recursive).
%   [sofa_paths, sofa_names] = LIST_SOFA_FILES_IN_FOLDER(sofa_dir) returns
%   full paths and basenames (without .sofa) sorted alphabetically.
%
%   Errors if the folder is missing or contains no .sofa files.

if nargin < 1 || isempty(sofa_dir)
    error('list_sofa_files_in_folder:MissingDir', ...
        'A SOFA directory path must be provided.');
end

if ~isfolder(sofa_dir)
    error('list_sofa_files_in_folder:DirNotFound', ...
        ['SOFA folder not found: %s. Check multi_hrtf_sofa_dir or run ', ...
        'download_sonicom_hrtfs to populate the folder.'], sofa_dir);
end

listing = dir(fullfile(sofa_dir, '*.sofa'));
if isempty(listing)
    error('list_sofa_files_in_folder:NoSofaFiles', ...
        ['No .sofa files found in %s. Check multi_hrtf_sofa_dir or run ', ...
        'download_sonicom_hrtfs to populate the folder.'], sofa_dir);
end

[~, sort_idx] = sort({listing.name});
listing = listing(sort_idx);

sofa_paths = cell(1, numel(listing));
sofa_names = cell(1, numel(listing));
for k = 1:numel(listing)
    sofa_paths{k} = fullfile(listing(k).folder, listing(k).name);
    [~, sofa_names{k}] = fileparts(listing(k).name);
end
end
