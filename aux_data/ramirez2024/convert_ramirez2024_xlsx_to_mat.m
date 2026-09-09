%CONVERT_RAMIREZ2024_XLSX_TO_MAT Parse Table S2 xlsx into ramirez2024_trials.mat.
%
%   Run once from the repository root. If the xlsx is missing,
%   download_ramirez2024 is called first.
%   The loader (load_ramirez2024) reads the generated .mat at runtime.

this_dir = fileparts(mfilename('fullpath'));
repo_root = fileparts(fileparts(this_dir));
if ~isfolder(fullfile(repo_root, 'aux_data', 'ramirez2024'))
  error('Run this script from within the repository (aux_data/ramirez2024 not found).');
end
cd(repo_root);

xlsx_name = 'Table S2_Data_Experimental raw data.xlsx';
source_xlsx = fullfile('aux_data', 'ramirez2024', xlsx_name);
addpath(this_dir);
download_ramirez2024();
if ~isfile(source_xlsx)
  error('Missing xlsx file: %s', source_xlsx);
end

raw = readcell(source_xlsx);
left = parse_ramirez2024_block(raw, 1, 2, 3, 4, 5, 6, 7, 8);
right = parse_ramirez2024_block(raw, 10, 11, 12, 13, 14, 15, 16, 17);
trials = [left; right];

expected_rows = 19 * 37;
if height(trials) ~= expected_rows
  error('Expected %d trial rows, got %d.', expected_rows, height(trials));
end

out_file = fullfile('aux_data', 'ramirez2024', 'ramirez2024_trials.mat');
converted_on = datetime('now');
save(out_file, 'trials', 'source_xlsx', 'converted_on');
fprintf('Saved %s (%d rows).\n', out_file, height(trials));

function block = parse_ramirez2024_block(raw, col_pid, col_trial, ...
    col_c1_obj, col_c1_sub, col_c2_obj, col_c2_sub, col_c3_obj, col_c3_sub)

n_rows = size(raw, 1);
participant_id = NaN;
rows = {};

for r = 1:n_rows
  pid_val = raw{r, col_pid};
  if ~isempty(pid_val) && ~(ischar(pid_val) && strcmp(strtrim(pid_val), 'Participant'))
    new_pid = parse_numeric_cell(pid_val);
    if ~isnan(new_pid)
      participant_id = new_pid;
    end
  end

  trial_val = raw{r, col_trial};
  if isempty(trial_val) || (ischar(trial_val) && strcmp(trial_val, 'Trial #'))
    continue;
  end
  trial_num = parse_numeric_cell(trial_val);
  if isnan(trial_num)
    continue;
  end

  c1_obj = parse_numeric_cell(raw{r, col_c1_obj});
  c1_sub = parse_numeric_cell(raw{r, col_c1_sub});
  c2_obj = parse_numeric_cell(raw{r, col_c2_obj});
  c2_sub = parse_numeric_cell(raw{r, col_c2_sub});
  c3_obj = parse_numeric_cell(raw{r, col_c3_obj});
  c3_sub = parse_numeric_cell(raw{r, col_c3_sub});

  if any(isnan([c1_obj, c1_sub, c2_obj, c2_sub, c3_obj, c3_sub]))
    continue;
  end

  rows(end + 1, :) = {participant_id, trial_num, c1_obj, c1_sub, ...
    c2_obj, c2_sub, c3_obj, c3_sub}; %#ok<AGROW>
end

block = cell2table(rows, 'VariableNames', { ...
  'ParticipantID', 'Trial', ...
  'C1_ObjectiveDeg', 'C1_SubjectiveDeg', ...
  'C2_ObjectiveDeg', 'C2_SubjectiveDeg', ...
  'C3_ObjectiveDeg', 'C3_SubjectiveDeg'});
end

function val = parse_numeric_cell(x)
  if isnumeric(x) && isscalar(x)
  val = double(x);
elseif ischar(x) || isstring(x)
  txt = strtrim(char(string(x)));
  if isempty(txt)
    val = NaN;
  else
    val = str2double(txt);
  end
else
  val = NaN;
end
end
