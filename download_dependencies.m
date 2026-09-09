function summary = download_dependencies()
%download_dependencies - Download public HRTFs, datasets, and Stitt code
%   download_dependencies() fetches the publicly available files needed
%   before compare_models_to_perceptual_data: the eight HRTF SOFA files,
%   frank2013 and ramirez2024 perceptual data, and the Stitt et al.
%   extended energy-vector MATLAB code. Existing files are skipped.
%
%   SUMMARY = download_dependencies() also returns a struct with per-step
%   status and a list of items that must still be obtained by hand.
%
%   See also download_hrtfs, download_frank2013, download_ramirez2024,
%   download_stitt2016, convert_ramirez2024_xlsx_to_mat,
%   compare_models_to_perceptual_data
%
%   Note: simon2010, desena2013, and llado2026 are not downloaded here

repo_root = fileparts(mfilename('fullpath'));
old_dir = pwd;
cleanup_obj = onCleanup(@() cd(old_dir));
cd(repo_root);

addpath(fullfile(repo_root, 'aux_data', 'HRTFs'));
addpath(fullfile(repo_root, 'aux_data', 'frank2013'));
addpath(fullfile(repo_root, 'aux_data', 'ramirez2024'));
addpath(fullfile(repo_root, 'models', 'extended_re'));

fprintf('Downloading public dependencies into %s\n', repo_root);

steps = [ ...
    run_named_step('hrtfs', @() download_hrtfs_or_fail()), ...
    run_named_step('frank2013', @() download_frank2013()), ...
    run_named_step('ramirez2024', @() convert_ramirez2024(repo_root)), ...
    run_named_step('stitt2016', @() download_stitt2016())];

summary = struct();
summary.steps = steps;
summary.manual = report_manual_items(repo_root);

fprintf('\n==== Public download summary ====\n');
for iStep = 1:numel(steps)
    if steps(iStep).ok
        status = 'ok';
    else
        status = 'FAILED';
    end
    fprintf('  %-14s %s\n', steps(iStep).id, status);
end

print_manual_report(summary.manual);

failed_ids = {steps(~[steps.ok]).id};
if ~isempty(failed_ids)
    error('download_dependencies:DownloadFailed', ...
        'One or more public downloads failed: %s.', strjoin(failed_ids, ', '));
end
end

function result = run_named_step(step_id, fun)
fprintf('\n---- %s ----\n', step_id);
result = struct('id', step_id, 'ok', true, 'message', 'ok');
try
    fun();
catch err
    result.ok = false;
    result.message = err.message;
    warning('download_dependencies:StepFailed', '%s: %s', step_id, err.message);
end
end

function download_hrtfs_or_fail()
hrtf_summary = download_hrtfs();
if ~isempty(hrtf_summary.failed)
    error('download_dependencies:HrtfFailed', ...
        'Failed HRTF downloads: %s', strjoin(hrtf_summary.failed, ', '));
end
end

function convert_ramirez2024(repo_root)
script_path = fullfile(repo_root, 'aux_data', 'ramirez2024', ...
    'convert_ramirez2024_xlsx_to_mat.m');
run(script_path);
end

function manual = report_manual_items(repo_root)
desena_dir = fullfile(repo_root, 'aux_data', 'DeSena2013', ...
    'results_localisation_desena2013');
cache_dir = fullfile(repo_root, 'model_output_data');
cache_files = dir(fullfile(cache_dir, 'MC_MODEL_OUTPUT_*.mat'));

amt_present = false;
amt_detail = 'set amt_dir in local_paths.m';
local_paths_file = fullfile(repo_root, 'local_paths.m');
if isfile(local_paths_file)
    try
        lp = local_paths();
        amt_present = isfile(fullfile(lp.amt_dir, 'amt_start.m'));
        amt_detail = lp.amt_dir;
    catch
        amt_detail = 'could not read local_paths.m';
    end
end

manual = [ ...
    item_status('local_paths.m', isfile(local_paths_file), ...
        'copy local_paths_template.m and edit paths'), ...
    item_status('AMT', amt_present, amt_detail), ...
    item_status('simon2010', ...
        isfile(fullfile(repo_root, 'aux_data', 'Simon2010', ...
        'simon2010_trials.mat')), ...
        'from authors, then convert_simon2010_xls_to_mat'), ...
    item_status('desena2013', isfolder(desena_dir) && has_subfolders(desena_dir), ...
        'from authors: results_localisation_desena2013/'), ...
    item_status('llado2026', ...
        isfile(fullfile(repo_root, 'aux_data', 'llado2026', 'expResultsTable.mat')) ...
        && isfile(fullfile(repo_root, 'aux_data', 'llado2026', ...
        'llado2026_allresults.mat')), ...
        'from authors: expResultsTable.mat and llado2026_allresults.mat'), ...
    item_status('model_output_cache', ~isempty(cache_files), ...
        'from authors, or recompute after dependencies are in place')];
end

function row = item_status(id, present, detail)
row = struct('id', id, 'present', present, 'detail', detail);
end

function tf = has_subfolders(folder_path)
listing = dir(folder_path);
names = {listing.name};
tf = any([listing.isdir] & ~ismember(names, {'.', '..'}));
end

function print_manual_report(manual)
fprintf('\n==== Items not downloaded automatically ====\n');
for iItem = 1:numel(manual)
    if manual(iItem).present
        fprintf('  %-20s present\n', manual(iItem).id);
    else
        fprintf('  %-20s missing  %s\n', ...
            manual(iItem).id, manual(iItem).detail);
    end
end
fprintf(['\nRecompute-only toolboxes (PrecSep, phaselocknet, ei_yang, ' ...
    'WaveLoc/Docker) are configured in local_paths.m; see README.md.\n']);
end
