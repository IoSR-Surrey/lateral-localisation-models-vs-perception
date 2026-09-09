%CONVERT_SIMON2010_XLS_TO_MAT Parse resultsmain.xls into simon2010_trials.mat.
%
%   Run once from the repository root after adding or updating the xls file.
%   The loader (load_simon2010) reads the generated .mat at runtime.
%
%   Each V* sheet is one participant x session. Columns:
%     Fichier, Loudspeaker 1, Loudspeaker 2, Level Diff, Time Diff,
%     Perceived Azimuth, Perceived Locatedness

this_dir = fileparts(mfilename('fullpath'));
repo_root = fileparts(fileparts(this_dir));
if ~isfolder(fullfile(repo_root, 'aux_data', 'Simon2010'))
    error('Run this script from within the repository (aux_data/Simon2010 not found).');
end
cd(repo_root);

xls_name = 'resultsmain.xls';
source_xls = fullfile('aux_data', 'Simon2010', 'original data', xls_name);
if ~isfile(source_xls)
    error('Missing xls file: %s', source_xls);
end

[~, sheets] = xlsfinfo(source_xls);
part_sheets = sheets(startsWith(sheets, 'V '));
if numel(part_sheets) ~= 70
    error('Expected 70 participant sheets (10 x 7), found %d.', numel(part_sheets));
end

n_est = numel(part_sheets) * 120;
participant_id = zeros(n_est, 1);
session = zeros(n_est, 1);
material = strings(n_est, 1);
lsp1 = zeros(n_est, 1);
lsp2 = zeros(n_est, 1);
icld = zeros(n_est, 1);
ictd = zeros(n_est, 1);
perc_az_deg = zeros(n_est, 1);
locatedness = zeros(n_est, 1);
n_rows = 0;

for i_sheet = 1:numel(part_sheets)
    sheet_name = part_sheets{i_sheet};
    tok_subj = regexp(sheet_name, 'V (\d+)', 'tokens', 'once');
    if isempty(tok_subj)
        error('Could not parse participant id from sheet name "%s".', sheet_name);
    end
    subj = str2double(tok_subj{1});
    tok_sess = regexp(sheet_name, '\((\d+)\)', 'tokens', 'once');
    if isempty(tok_sess)
        sess = 1;
    else
        sess = str2double(tok_sess{1});
    end

    [num, ~, raw] = xlsread(source_xls, sheet_name);
    if size(num, 2) < 6
        error('Sheet "%s" has unexpected numeric size %s.', sheet_name, mat2str(size(num)));
    end

    n = size(num, 1);
    files = string(raw(2:(n + 1), 1));
    for i = 1:n
        mat_label = parse_simon2010_material(files(i));
        if mat_label == ""
            continue
        end
        if any(isnan(num(i, 1:6)))
            continue
        end
        n_rows = n_rows + 1;
        participant_id(n_rows) = subj;
        session(n_rows) = sess;
        material(n_rows) = mat_label;
        lsp1(n_rows) = num(i, 1);
        lsp2(n_rows) = num(i, 2);
        icld(n_rows) = num(i, 3);
        ictd(n_rows) = num(i, 4);
        perc_az_deg(n_rows) = num(i, 5);
        locatedness(n_rows) = num(i, 6);
    end
end

trials = table( ...
    participant_id(1:n_rows), ...
    session(1:n_rows), ...
    material(1:n_rows), ...
    lsp1(1:n_rows), ...
    lsp2(1:n_rows), ...
    icld(1:n_rows), ...
    ictd(1:n_rows), ...
    perc_az_deg(1:n_rows), ...
    locatedness(1:n_rows), ...
    'VariableNames', { ...
    'ParticipantID', 'Session', 'Material', ...
    'Lsp1', 'Lsp2', 'ICLD', 'ICTD', 'PercAzDeg', 'Locatedness'});

if height(trials) < 8000
    error('Expected ~8118 trial rows, got %d.', height(trials));
end

out_file = fullfile('aux_data', 'Simon2010', 'simon2010_trials.mat');
converted_on = datetime('now');
save(out_file, 'trials', 'source_xls', 'converted_on');
fprintf('Saved %s (%d rows, %d subjects, %d sessions).\n', ...
    out_file, height(trials), ...
    numel(unique(trials.ParticipantID)), numel(unique(trials.Session)));

function mat_label = parse_simon2010_material(file_name)
txt = lower(strtrim(char(file_name)));
txt = erase(txt, '''');
if contains(txt, 'noise')
    mat_label = "noise";
elseif contains(txt, 'voice')
    mat_label = "voice";
elseif contains(txt, 'cello')
    mat_label = "cello";
elseif contains(txt, 'percu')
    mat_label = "percu";
else
    mat_label = "";
end
end
