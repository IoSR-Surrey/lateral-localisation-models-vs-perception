function summary = download_hrtfs(output_dir)
%DOWNLOAD_HRTFS Download the 8 HRTF SOFA files used in the paper.
%
%   summary = DOWNLOAD_HRTFS() downloads the SOFA files into
%   aux_data/HRTFs/collection/ (relative to the repository root), which is the
%   default multi_hrtf_sofa_dir of compare_models_to_perceptual_data.m.
%   Re-running skips files that already exist.
%
%   summary = DOWNLOAD_HRTFS(output_dir) writes to output_dir instead.
%
%   HRTF sets (free-field compensated, minimum phase / measured, 48 kHz):
%     SONICOM HRTF dataset (Engel et al., 2023), participants P0001, P0003,
%       P0005, P0006:
%       https://www.axdesign.co.uk/tools-and-devices/sonicom-hrtf-dataset
%     ARI HRTF database (Acoustics Research Institute, Vienna), subjects
%       NH1059, NH1188, NH1189, NH1190:
%       https://www.oeaw.ac.at/isf/das-institut/software/hrtf-database
%       (served via https://sofacoustics.org/data/database/ari/)
%
%   The ARI files are saved as "hrtf d_nhXXXX.sofa" (the original file name,
%   including the space) because the cached model outputs are keyed by the
%   SOFA basename.

this_dir = fileparts(mfilename('fullpath'));
if nargin < 1 || isempty(output_dir)
    output_dir = fullfile(this_dir, 'collection');
end
if ~isfolder(output_dir)
    mkdir(output_dir);
end

sonicom_base = 'https://transfer.ic.ac.uk:9090/2022_SONICOM-HRTF-DATASET';
ari_base = 'https://sofacoustics.org/data/database/ari';

files = {};
for pid = [1, 3, 5, 6]
    label = sprintf('P%04d', pid);
    fname = [label '_FreeFieldCompMinPhase_48kHz.sofa'];
    files(end + 1, :) = {fname, ...
        sprintf('%s/%s/HRTF/HRTF/48kHz/%s', sonicom_base, label, fname)}; %#ok<AGROW>
end
for nh = [1059, 1188, 1189, 1190]
    fname = sprintf('hrtf d_nh%d.sofa', nh);
    files(end + 1, :) = {fname, ...
        sprintf('%s/hrtf%%20d_nh%d.sofa', ari_base, nh)}; %#ok<AGROW>
end

summary = struct('downloaded', {{}}, 'skipped', {{}}, 'failed', {{}});
for iFile = 1:size(files, 1)
    dest_path = fullfile(output_dir, files{iFile, 1});
    url = files{iFile, 2};
    if isfile(dest_path)
        summary.skipped{end + 1} = dest_path;
        fprintf('Skip (exists): %s\n', dest_path);
        continue
    end
    fprintf('Downloading %s ...\n', url);
    if download_one_file(url, dest_path)
        summary.downloaded{end + 1} = dest_path;
        fprintf('Saved: %s\n', dest_path);
    else
        summary.failed{end + 1} = url;
        warning('download_hrtfs:DownloadFailed', 'Failed to download %s', url);
    end
end

fprintf('\nHRTF download summary: %d downloaded, %d skipped, %d failed.\n', ...
    numel(summary.downloaded), numel(summary.skipped), numel(summary.failed));
end

function ok = download_one_file(url, dest_path)
try
    websave(dest_path, url);
    ok = isfile(dest_path);
catch
    ok = false;
end
if ok
    return
end
if isfile(dest_path)
    delete(dest_path);
end
% Fallback to curl (e.g. when MATLAB cannot validate the server certificate).
cmd = sprintf('curl -k -L -o "%s" "%s"', dest_path, url);
status = system(cmd);
ok = status == 0 && isfile(dest_path);
end
