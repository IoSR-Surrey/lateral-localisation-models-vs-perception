function all_passed = verify_ramirez2024_against_paper()
%VERIFY_RAMIREZ2024_AGAINST_PAPER Check imported data against published RMS errors.
%
%   all_passed = VERIFY_RAMIREZ2024_AGAINST_PAPER() loads ramirez2024_trials.mat
%   and compares per-condition RMS localization error statistics to Ramírez
%   et al. (2024), Trends in Hearing.

this_dir = fileparts(mfilename('fullpath'));
repo_root = fileparts(fileparts(this_dir));
mat_file = fullfile(repo_root, 'aux_data', 'ramirez2024', 'ramirez2024_trials.mat');
if ~isfile(mat_file)
  error('Missing %s. Run convert_ramirez2024_xlsx_to_mat first.', mat_file);
end

data = load(mat_file, 'trials');
trials = data.trials;

paper = struct( ...
  'C1', struct('mean', 7.99, 'std', 2.21), ...
  'C2', struct('mean', 13.16, 'std', 5.32), ...
  'C3', struct('mean', 11.94, 'std', 4.96));
mean_tol = 0.05;
std_tol = 0.1;

n_participants = numel(unique(trials.ParticipantID));
n_trials_per_participant = height(trials) / n_participants;
fprintf('Participants: %d, trials/participant: %.0f\n\n', n_participants, n_trials_per_participant);

assert(n_participants == 19, 'Expected 19 participants, got %d.', n_participants);
assert(abs(n_trials_per_participant - 37) < 1e-9, 'Expected 37 trials per participant.');

conditions = {'C1', 'C2', 'C3'};
all_passed = true;
summary = {};

for ic = 1:numel(conditions)
  cond = conditions{ic};
  obj_col = cond + "_ObjectiveDeg";
  sub_col = cond + "_SubjectiveDeg";
  [mean_rms, std_rms, rms_per_participant] = ramirez2024_rms_error( ...
    trials.(obj_col), trials.(sub_col), trials.ParticipantID);

  pass_mean = abs(mean_rms - paper.(cond).mean) <= mean_tol;
  pass_std = abs(std_rms - paper.(cond).std) <= std_tol;
  passed = pass_mean && pass_std;
  all_passed = all_passed && passed;

  summary(end + 1, :) = {cond, mean_rms, paper.(cond).mean, pass_mean, ...
    std_rms, paper.(cond).std, pass_std, passed}; %#ok<AGROW>

  if ~passed
    fprintf('%s per-participant RMS (deg):\n', cond);
    disp(rms_per_participant(:)');
  end
end

T = cell2table(summary, 'VariableNames', { ...
  'Condition', 'MeanComputed', 'MeanPaper', 'MeanPass', ...
  'StdComputed', 'StdPaper', 'StdPass', 'AllPass'});
disp(T);

% Informational C1 regional and VBAP-only stats.
obj = trials.C1_ObjectiveDeg;
sub = trials.C1_SubjectiveDeg;
pid = trials.ParticipantID;
frontal_mask = abs(obj) <= 45;
lateral_mask = abs(obj) > 45;
vbap_mask = ~ismember(obj, [-90 -45 0 45 90]);

[mean_front, std_front] = ramirez2024_rms_error(obj(frontal_mask), sub(frontal_mask), pid(frontal_mask));
[mean_lat, std_lat] = ramirez2024_rms_error(obj(lateral_mask), sub(lateral_mask), pid(lateral_mask));
[mean_vbap, std_vbap] = ramirez2024_rms_error(obj(vbap_mask), sub(vbap_mask), pid(vbap_mask));

fprintf('\nC1 regional (informational):\n');
fprintf('  Frontal |obj|<=45: mean=%.2f deg, std=%.2f deg\n', mean_front, std_front);
fprintf('  Lateral |obj|>45:  mean=%.2f deg, std=%.2f deg\n', mean_lat, std_lat);
fprintf('  VBAP-only (32 dirs): mean=%.2f deg, std=%.2f deg\n', mean_vbap, std_vbap);

if ~all_passed
  error('verify_ramirez2024_against_paper: one or more paper checks failed.');
end
fprintf('\nAll paper RMS checks passed.\n');
end

function [mean_rms, std_rms, rms_per_participant] = ramirez2024_rms_error( ...
    objective_deg, subjective_deg, participant_id)

participants = unique(participant_id, 'stable');
n_participants = numel(participants);
rms_per_participant = zeros(n_participants, 1);

for ip = 1:n_participants
  mask = participant_id == participants(ip);
  err = objective_deg(mask) - subjective_deg(mask);
  rms_per_participant(ip) = sqrt(mean(err .^ 2));
end

mean_rms = mean(rms_per_participant);
std_rms = std(rms_per_participant);
end
