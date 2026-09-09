function listexp_data = load_listexp_data(authoryear, flag_plot_listexp, opts)
%LOAD_LISTEXP_DATA Load perceptual lateral-angle data for a listening experiment.
%
%   listexp_data = LOAD_LISTEXP_DATA(authoryear, flag_plot_listexp) returns a
%   struct with the perceptual responses for the requested dataset.
%   listexp_data = LOAD_LISTEXP_DATA(authoryear, flag_plot_listexp, opts)
%
%   Inputs
%       authoryear         Dataset id: 'desena2013', 'simon2010',
%                          'simon2010_separate', 'llado2026', 'ramirez2024',
%                          or 'frank2013'.
%                          'simon2010_separate' forces hemisphere 'separate'.
%       flag_plot_listexp  If 1, plot the data while loading (desena2013 only).
%       opts               Optional struct. For simon2010:
%                          .simon2010_hemisphere = 'fold_lr' | 'separate'
%                          Model simulation/cache always uses 'separate';
%                          'fold_lr' is the paper-style L/R pooled analysis view
%                          (also rebuilt from separate via apply_simon2010_hemisphere_view).
%
%   Common output fields
%       avgResponseVector  [nCond x 1] mean perceived lateral angle per
%                          condition. This is the ground truth fitted against
%                          model predictions. Positive = left. Off-centre
%                          desena2013 and frank2013 responses are converted
%                          from array-centre (world) angles into the
%                          listener/head frame (0 = nose) so they match
%                          model estimates. llado2026 is already listener-
%                          relative. Centre poses are an identity mapping.
%       r2_resample        Struct describing the bootstrap resampling scheme
%                          ('nested', 'trial', or 'condition'); see
%                          bootstrap_r2_ci.
%   Datasets also attach dataset-specific fields (e.g. avgResponse,
%   stdResponseVector, extended_re_meta) used by downstream analyses.

if nargin < 2 || isempty(flag_plot_listexp)
    flag_plot_listexp = 0;
end
if nargin < 3 || isempty(opts)
    opts = struct();
end

switch authoryear
    case 'desena2013'
        listexp_data = load_desena2013(flag_plot_listexp);
    case {'simon2010', 'simon2010_separate'}
        simon_mode = resolve_simon2010_hemisphere(authoryear, opts);
        listexp_data = load_simon2010(simon_mode);
    case 'llado2026'
        listexp_data = load_llado2026();
    case 'ramirez2024'
        listexp_data = load_ramirez2024();
    case 'frank2013'
        listexp_data = load_frank2013();
    otherwise
        listexp_data = 'no_data_available';
end
end

function mode = resolve_simon2010_hemisphere(authoryear, opts)
if strcmp(authoryear, 'simon2010_separate')
    mode = 'separate';
elseif isfield(opts, 'simon2010_hemisphere') && ~isempty(opts.simon2010_hemisphere)
    mode = char(string(opts.simon2010_hemisphere));
else
    mode = 'fold_lr';
end
if ~ismember(mode, {'fold_lr', 'separate'})
    error('simon2010: simon2010_hemisphere must be ''fold_lr'' or ''separate'', got ''%s''.', mode);
end
end

function listexp_data = load_desena2013(flag_plot_listexp)
%LOAD_DESENA2013 De Sena et al. (2013) multichannel localisation data.
%
% Response columns per trial: [system, actual_angle, perceived_angle,
% do_not_know, response_time]; loudspeaker layouts are 4 rendering methods
% (TINTD, HOA, HOA in-phase, TD) x 8 target angles x 2 seating positions.
% Off-centre seating (0.3 m at 135 deg) pointer angles are converted from
% the array-centre frame into the listener/head frame (yaw = 0).

data_dir = 'aux_data/DeSena2013/results_localisation_desena2013/';

% Discover listener result directories (skip dotfiles and non-data folders).
listing = dir(data_dir);
keep = ~startsWith({listing.name}, '.') ...
    & ~contains({listing.name}, 'training') ...
    & ~contains({listing.name}, 'analyse_data') ...
    & ~contains({listing.name}, 'subplot1') ...
    & ~contains({listing.name}, 'MODEL');
directories = {listing(keep).name};

NDirectories = numel(directories);
NSystems = {4, 4, 2, 2};
% Perceived-angle index -> angle lookup, per seating position.
angles = {-36:8:36, -36:8:36, 36:8:108, 108:8:180};
NAngles = 8;
NRepetitions = 4 * NDirectories;

% Plot styling (used only when flag_plot_listexp == 1).
systems = {'TINTD $N=2$', 'HOA $N=2$', 'HOA--in-phase $N=2$', 'TD $N=\infty$'};
colors = {[0.078 0.169 0.549], [0.0 1.0 0.0], [0.502 0.502 0.502], [1.0 0.0 0.0]};
marker_type = {'.', 'none', 'diamond', 'x'};
marker_size = {15.0, 6.0, 6.0, 6.0};
axis_cord = [-28-3.08, 28+3.08, -36, 36
             -28-3.08, 28+3.08, -36, 36
             44-3.08, 100+3.08, 36, 108
             116-3.08, 172+3.08, 108, 180];

% Per-listener, per-condition repetition responses for the nested R^2
% bootstrap. Dimensions: [condition x listener x repetition], aligned to the
% avgResponseVector ordering built below.
nMethods = NSystems{1};
nReps = NRepetitions / NDirectories;
desena_trials = nan(2 * NAngles * nMethods, NDirectories, nReps);
desena_counts = zeros(2 * NAngles * nMethods, NDirectories);

% Ring geometry matching generate_stimuli / re_get_trial_lsp_metadata.
desena_lsp_radius_m = 2;
desena_off_radius_m = 0.3;
desena_off_angle_deg = 135;

avgResponse = cell(1, 2);
stdResponse = cell(1, 2);
for nSeating = 1:2
    avgResponse{nSeating} = zeros(NSystems{nSeating}, NAngles);
    stdResponse{nSeating} = zeros(NSystems{nSeating}, NAngles);

    if nSeating == 1
        lis_front_m = 0;
        lis_left_m = 0;
    else
        lis_front_m = desena_off_radius_m * cosd(desena_off_angle_deg);
        lis_left_m = desena_off_radius_m * sind(desena_off_angle_deg);
    end

    % Pool all listeners, tagging each trial with its listener id (column 6).
    data = [];
    for nDir = 1:NDirectories
        loaded = load(fullfile(data_dir, directories{nDir}, ['response_sm' num2str(nSeating)]));
        resp = loaded.resp;
        data = [data; resp, nDir * ones(size(resp, 1), 1)]; %#ok<AGROW>
    end

    % Map the extreme "=>" / "<=" pointer indices (9, 10) onto 0 and 9, then
    % convert perceived-angle indices to angles.
    dataFiltered = data;
    dataFiltered(dataFiltered(:, 3) == 9, 3) = 0;
    dataFiltered(dataFiltered(:, 3) == 10, 3) = 9;
    dataFiltered(:, 3) = angles{nSeating}(dataFiltered(:, 3) + 1);

    if flag_plot_listexp == 1
        figure
        paper_mean = zeros(NSystems{nSeating}, NAngles);
        paper_std = zeros(NSystems{nSeating}, NAngles);
    end

    for nSystem = 1:NSystems{nSeating}
        for nAngle = 1:NAngles
            sel = dataFiltered(:, 2) == nAngle & dataFiltered(:, 1) == nSystem;
            assert(sum(sel) == NRepetitions);
            paper_resp = dataFiltered(sel, 3);
            % Paper angles use the opposite sign; convert after flipping so
            % positive = left, then map array-centre pointers into the
            % listener/head frame (identity at the centre seat).
            listener_az = world_az_to_listener_az( ...
                -paper_resp, lis_left_m, lis_front_m, desena_lsp_radius_m, 0);
            avgResponse{nSeating}(nSystem, nAngle) = mean(listener_az);
            stdResponse{nSeating}(nSystem, nAngle) = std(listener_az);

            % Per-listener repetitions for the nested bootstrap, in
            % avgResponseVector condition ordering.
            cond_index = (nSeating - 1) * (NAngles * nMethods) ...
                + (nAngle - 1) * nMethods + nSystem;
            for nListener = 1:NDirectories
                listener_rows = sel & dataFiltered(:, 6) == nListener;
                listener_resp = world_az_to_listener_az( ...
                    -dataFiltered(listener_rows, 3), lis_left_m, lis_front_m, ...
                    desena_lsp_radius_m, 0);
                nThisRep = numel(listener_resp);
                desena_trials(cond_index, nListener, 1:nThisRep) = listener_resp;
                desena_counts(cond_index, nListener) = nThisRep;
            end

            if flag_plot_listexp == 1
                paper_mean(nSystem, nAngle) = mean(paper_resp);
                paper_std(nSystem, nAngle) = std(paper_resp);
            end
        end

        if flag_plot_listexp == 1
            errorbar(angles{nSeating}(2:end-1), ...
                paper_mean(nSystem, :), ...
                paper_std(nSystem, :) / sqrt(NRepetitions) * 2, ...
                'Color', colors{nSystem}, 'Marker', marker_type{nSystem}, ...
                'MarkerSize', marker_size{nSystem}, 'LineWidth', 0.5);
            hold on
        end
    end

    if flag_plot_listexp == 1
        plot([angles{nSeating}(2)-3.08 angles{nSeating}(end-1)+3.08], ...
            [angles{nSeating}(2)-3.08 angles{nSeating}(end-1)+3.08], '--', ...
            'Color', [0.502 0.502 0.502]);
        h = legend(systems{1:NSystems{nSeating}}, 'Location', 'NorthWest');
        set(h, 'EdgeColor', [1 1 1]);
        set(h, 'FontSize', 8);
        axis(axis_cord(nSeating, :))
        set(gca, 'YTick', angles{nSeating})
        set(gca, 'XTick', angles{nSeating}(2:end-1))
        xlabel('Stimulus angle [deg]')
        ylabel('Mean response angle [deg]')
    end
end

% Stack seatings into [seating x method x angle] arrays.
listexp_data = struct();
listexp_data.avgResponse = cat(3, avgResponse{1}, avgResponse{2});
listexp_data.avgResponse = permute(listexp_data.avgResponse, [3 1 2]);
listexp_data.stdResponse = cat(3, stdResponse{1}, stdResponse{2});
listexp_data.stdResponse = permute(listexp_data.stdResponse, [3 1 2]);

% Flatten to vectors with ordering: method (fastest), angle, seating (slowest).
% avgResponse is [seating x method x angle] in the listener frame with
% positive = left, so permute to [method x angle x seating] before reshaping
% column-major.
listexp_data.avgResponseVector = reshape(permute(listexp_data.avgResponse, [2 3 1]), [], 1);
listexp_data.stdResponseVector = reshape(permute(listexp_data.stdResponse, [2 3 1]), [], 1);

% Nested-bootstrap support, aligned with avgResponseVector ordering.
listexp_data.r2_resample = struct('unit', 'nested', ...
    'trials', desena_trials, 'counts', desena_counts);
listexp_data.desena2013_NRepetitions = NRepetitions;
listexp_data.desena2013_filter_meta = re_compute_desena2013_lsp_filter_metadata();
end

function listexp_data = load_simon2010(hemisphere_mode)
%LOAD_SIMON2010 Simon (2010) two-loudspeaker localisation data.
% avgResponse columns: [ICLD, ICTD_ms, lsp1_angle, lsp2_angle, perceived_angle].
%
% hemisphere_mode:
%   'fold_lr'  - Paper-style: mirror right-hemisphere trials onto left and
%                average over the pooled set (default).
%   'separate' - Keep right-hemisphere pairs as their own conditions with
%                signed (negative) angles; correlation plots extend to both sides.

if nargin < 1 || isempty(hemisphere_mode)
    hemisphere_mode = 'fold_lr';
end

mat_file = fullfile('aux_data', 'Simon2010', 'simon2010_trials.mat');
if ~isfile(mat_file)
    error(['simon2010: missing %s. Run convert_simon2010_xls_to_mat.m.'], mat_file);
end

trials = load(mat_file, 'trials').trials;

% Left: 1->0, 8->45, 7->90, 6->135, 5->180
% Right: 1->0, 2->-45, 3->-90, 4->-135, 5->-180 (positive = left)
left_lsp_ids = [1 8; 8 7; 7 6; 6 5];
right_lsp_ids = [1 2; 2 3; 3 4; 4 5];
left_pos = [0 45; 45 90; 90 135; 135 180];
right_pos = [0 -45; -45 -90; -90 -135; -135 -180];

left_rows = collect_simon2010_hemisphere(trials, left_lsp_ids, left_pos, false);

if strcmp(hemisphere_mode, 'fold_lr')
    % Mirror right onto left figure frame and pool (interaural symmetry).
    right_mirrored = collect_simon2010_hemisphere(trials, right_lsp_ids, left_pos, true);
    canon_rows = [left_rows; right_mirrored];
    lsp_pos_cells = {left_pos(1, :), left_pos(2, :), left_pos(3, :), left_pos(4, :)};
    pair_angles = left_pos;
else
    right_rows = collect_simon2010_hemisphere(trials, right_lsp_ids, right_pos, false);
    % Offset right pair indices so they stay distinct from left.
    right_rows(:, 1) = right_rows(:, 1) + size(left_pos, 1);
    canon_rows = [left_rows; right_rows];
    pair_angles = [left_pos; right_pos];
    lsp_pos_cells = cell(1, size(pair_angles, 1));
    for ip = 1:size(pair_angles, 1)
        lsp_pos_cells{ip} = pair_angles(ip, :);
    end
end

subjects = unique(canon_rows(:, 5), 'stable');
n_subjects = numel(subjects);

cond_keys = unique(canon_rows(:, 1:3), 'rows', 'stable');
[~, cond_order] = sortrows(cond_keys, [1 2 3]);
cond_keys = cond_keys(cond_order, :);
n_conditions = size(cond_keys, 1);

avgResponse = zeros(n_conditions, 5);
stdResponseVector = zeros(n_conditions, 1);
nTrials = zeros(n_conditions, 1);
subj_cond = cell(n_conditions, n_subjects);
max_t = 0;

for i_cond = 1:n_conditions
    pair_idx = cond_keys(i_cond, 1);
    ictd = cond_keys(i_cond, 2);
    icld = cond_keys(i_cond, 3);
    mask = canon_rows(:, 1) == pair_idx ...
        & canon_rows(:, 2) == ictd ...
        & canon_rows(:, 3) == icld;
    resp = canon_rows(mask, 4);
    avgResponse(i_cond, :) = [icld, ictd, pair_angles(pair_idx, 1), ...
        pair_angles(pair_idx, 2), mean(resp, 'omitnan')];
    stdResponseVector(i_cond) = std(resp, 0, 'omitnan');
    nTrials(i_cond) = numel(resp);

    for i_subj = 1:n_subjects
        subj_vals = resp(canon_rows(mask, 5) == subjects(i_subj));
        subj_vals = subj_vals(~isnan(subj_vals));
        subj_cond{i_cond, i_subj} = subj_vals(:);
        max_t = max(max_t, numel(subj_vals));
    end
end

trials_nested = nan(n_conditions, n_subjects, max(max_t, 1));
counts = zeros(n_conditions, n_subjects);
for i_cond = 1:n_conditions
    for i_subj = 1:n_subjects
        subj_vals = subj_cond{i_cond, i_subj};
        k = numel(subj_vals);
        if k > 0
            trials_nested(i_cond, i_subj, 1:k) = subj_vals;
        end
        counts(i_cond, i_subj) = k;
    end
end

listexp_data = struct();
listexp_data.lsp_pos_Simon = lsp_pos_cells;
listexp_data.avgResponse = avgResponse;
% Column 5 is the perceived left-side angle (positive = left), matching the
% unswapped binaural signals in generate_stimuli.
listexp_data.avgResponseVector = avgResponse(:, 5);
listexp_data.stdResponseVector = stdResponseVector;
listexp_data.nTrials = nTrials;
listexp_data.simon2010_hemisphere = hemisphere_mode;
listexp_data.r2_resample = struct('unit', 'nested', ...
    'trials', trials_nested, 'counts', counts);
end

function rows = collect_simon2010_hemisphere(trials, lsp_ids, pair_angles, mirror_to_left)
% Collect canonical trials for one hemisphere.
% rows columns: [pair_idx, ICTD, ICLD, PercLatDeg, ParticipantID]
% When mirror_to_left is true, negate perceived azimuth before folding into
% pair_angles (used to pool right onto left under interaural symmetry).
% ICLD/ICTD use H1: negate both when speaker order is reversed so cues apply
% to the higher-|azimuth| / side loudspeaker.
%
% The raw xls ICTD sign is opposite to the convention used by the rest of the
% pipeline. generate_stimuli advances the second (side) loudspeaker for a
% positive ICTD (drawing perception toward az2), and re_get_trial_lsp_metadata
% delays the first loudspeaker for a positive ICTD (also toward az2). In the raw
% xls, a positive ICTD instead draws perception toward the first (front)
% loudspeaker az1 (verified against the ICLD=0 sweeps and the figure-digitized
% mats, which match the raw means only after flipping ICTD). Negate the raw ICTD
% here so column 2 matches generate_stimuli / extended-rE and the previously
% well-fitting figure convention. ICLD needs no flip.

n = height(trials);
rows = zeros(0, 5);
for i = 1:n
    a = trials.Lsp1(i);
    b = trials.Lsp2(i);
    up = sort([a b]);
    matched = false;
    for p = 1:size(lsp_ids, 1)
        if isequal(up, sort(lsp_ids(p, :)))
            matched = true;
            pid = p;
            break
        end
    end
    if ~matched
        continue
    end

    order = lsp_ids(pid, :);
    icld = trials.ICLD(i);
    ictd = -trials.ICTD(i);
    if a == order(1) && b == order(2)
        cicld = icld;
        cictd = ictd;
    elseif a == order(2) && b == order(1)
        cicld = -icld;
        cictd = -ictd;
    else
        continue
    end

    az1 = pair_angles(pid, 1);
    az2 = pair_angles(pid, 2);
    perc = trials.PercAzDeg(i);
    if mirror_to_left
        perc = -perc;
    end
    lat = simon2010_fold_perc_az(perc, az1, az2);
    rows(end + 1, :) = [pid, cictd, cicld, lat, trials.ParticipantID(i)]; %#ok<AGROW>
end
end

function lat = simon2010_fold_perc_az(az_deg, az1, az2)
% Unwrap toward the pair midpoint, then fold rear azimuths to lateral angle.
% Positive = left. For right-hemisphere pairs (negative az), fold az < -90
% with lat = -180 - az (mirror of the left-side 180 - az rule).
mid = (az1 + az2) / 2;
az_u = mid + (mod(az_deg - mid + 180, 360) - 180);
if az_u > 90
    lat = 180 - az_u;
elseif az_u < -90
    lat = -180 - az_u;
else
    lat = az_u;
end
end

function listexp_data = load_llado2026()
%LOAD_LLADO2026 Llado et al. (2026) ICTD/ICLD lateralization data (submitted, AVAR).
% Conditions vary listener position (P0..P3), inter-channel time and level
% differences. All positions, conditions and presentation modes (BIN + LSP)
% are pooled.

exp_data = load('aux_data/llado2026/expResultsTable.mat');
exp_table = exp_data.expTable;
all_results = load('aux_data/llado2026/llado2026_allresults.mat').allResults;

n_conditions = height(exp_table);
MeanLatDeg = nan(n_conditions, 1);
StdLatDeg = nan(n_conditions, 1);
NTrials = zeros(n_conditions, 1);

% Nested R^2 bootstrap support: collect per-subject, per-condition trial
% responses. SwapFlag == 1 trials have left/right swapped, so the lateral
% angle must be negated; this reproduces expTable.MeanLatDeg exactly.
subjects = unique(all_results.ParticipantID, 'stable');
n_subjects = numel(subjects);
subj_cond = cell(n_conditions, n_subjects);
maxT = 0;

for iCond = 1:n_conditions
    row = exp_table(iCond, :);
    mask = all_results.PositionLabel == row.PositionLabel ...
        & all_results.ICTD == row.ICTD ...
        & all_results.ICLD == row.ICLD;
    sub = all_results(mask, :);
    if isempty(sub)
        error('llado2026: no trials for Position=%s ICTD=%g ICLD=%g.', ...
            string(row.PositionLabel), row.ICTD, row.ICLD);
    end
    lat = sph2hor(sub.ResponseAzDeg, sub.ResponseElDeg);
    swap_mask = sub.SwapFlag == 1;
    lat(swap_mask) = -lat(swap_mask);
    MeanLatDeg(iCond) = mean(lat, 'omitnan');
    StdLatDeg(iCond) = std(lat, 0, 'omitnan');
    NTrials(iCond) = numel(lat);
    for iSubj = 1:n_subjects
        subj_vals = lat(sub.ParticipantID == subjects(iSubj));
        subj_vals = subj_vals(~isnan(subj_vals));
        subj_cond{iCond, iSubj} = subj_vals(:);
        maxT = max(maxT, numel(subj_vals));
    end
end

exp_table.MeanLatDeg = MeanLatDeg;
exp_table.NTrials = NTrials;
exp_table.StdLatDeg = StdLatDeg;

listexp_data = struct();
listexp_data.avgResponseVector = MeanLatDeg;
listexp_data.avgResponse = exp_table;
listexp_data.StdLatDeg = StdLatDeg;
listexp_data.stdResponseVector = StdLatDeg;

% Pad ragged per-subject trials into [condition x subject x trial] arrays.
trials = nan(n_conditions, n_subjects, max(maxT, 1));
counts = zeros(n_conditions, n_subjects);
for iCond = 1:n_conditions
    for iSubj = 1:n_subjects
        subj_vals = subj_cond{iCond, iSubj};
        k = numel(subj_vals);
        if k > 0
            trials(iCond, iSubj, 1:k) = subj_vals;
        end
        counts(iCond, iSubj) = k;
    end
end
listexp_data.r2_resample = struct('unit', 'nested', 'trials', trials, 'counts', counts);

% Precompute per-trial extended-rE loudspeaker metadata once, so the model
% loop does not re-read expResultsTable.mat for every trial.
listexp_data.extended_re_meta = build_llado2026_re_meta(exp_table);
end

function listexp_data = load_ramirez2024()
%LOAD_RAMIREZ2024 Ramírez et al. (2024) C1 loudspeaker localisation (VBAP-only).
% Uses pre-converted trial table; run convert_ramirez2024_xlsx_to_mat if missing.

mat_file = fullfile('aux_data', 'ramirez2024', 'ramirez2024_trials.mat');
if ~isfile(mat_file)
    error(['ramirez2024: missing %s. Run convert_ramirez2024_xlsx_to_mat.m.'], mat_file);
end

trials = load(mat_file, 'trials').trials;
lsp_az_deg = [-90 -45 0 45 90];
vbap_only_az_deg = setdiff(-90:5:90, lsp_az_deg);

c1_mask = ismember(trials.C1_ObjectiveDeg, vbap_only_az_deg);
c1_trials = trials(c1_mask, :);

subjects = unique(c1_trials.ParticipantID, 'stable');
n_subjects = numel(subjects);
n_conditions = numel(vbap_only_az_deg);

avg_table = table('Size', [n_conditions, 4], ...
    'VariableTypes', {'double', 'double', 'double', 'double'}, ...
    'VariableNames', {'ObjectiveDeg', 'MeanSubjectiveDeg', 'StdSubjectiveDeg', 'NSubjects'});

avgResponseVector = zeros(n_conditions, 1);
stdResponseVector = zeros(n_conditions, 1);
trials_nested = nan(n_conditions, n_subjects, 1);
counts = zeros(n_conditions, n_subjects);

for iCond = 1:n_conditions
    obj_deg = vbap_only_az_deg(iCond);
    mask = c1_trials.C1_ObjectiveDeg == obj_deg;
    subj_resp = -c1_trials.C1_SubjectiveDeg(mask);
    avgResponseVector(iCond) = mean(subj_resp);
    stdResponseVector(iCond) = std(subj_resp, 0, 'omitnan');

    avg_table.ObjectiveDeg(iCond) = obj_deg;
    avg_table.MeanSubjectiveDeg(iCond) = avgResponseVector(iCond);
    avg_table.StdSubjectiveDeg(iCond) = stdResponseVector(iCond);
    avg_table.NSubjects(iCond) = n_subjects;

    for iSubj = 1:n_subjects
        subj_mask = mask & c1_trials.ParticipantID == subjects(iSubj);
        val = -c1_trials.C1_SubjectiveDeg(subj_mask);
        if ~isempty(val)
            trials_nested(iCond, iSubj, 1) = val(1);
            counts(iCond, iSubj) = 1;
        end
    end
end

listexp_data = struct();
listexp_data.avgResponse = avg_table;
listexp_data.avgResponseVector = avgResponseVector;
listexp_data.stdResponseVector = stdResponseVector;
listexp_data.ramirez2024_lsp_az_deg = lsp_az_deg;
listexp_data.ramirez2024_vbap_only_az_deg = vbap_only_az_deg(:);
listexp_data.r2_resample = struct('unit', 'nested', 'trials', trials_nested, 'counts', counts);
listexp_data.extended_re_meta = build_ramirez2024_re_meta(vbap_only_az_deg, lsp_az_deg);
end

function listexp_data = load_frank2013()
%LOAD_FRANK2013 Frank (2013) VBAP localization on an 8-loudspeaker ring.
% Centre and off-centre (1.25 m left) listening positions; 9 pan directions
% from 0 deg to -45 deg (right). Uses read_frank2013_lococ for raw trials.
% Off-centre PercAngleDeg values are converted from the array-centre frame
% into the listener/head frame (listener faces the 0 deg loudspeaker).

repo_root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(repo_root, 'aux_data', 'frank2013'));
frank_data = read_frank2013_lococ();
trials = frank_data.trials;
trials = trials(trials.Method == "VBAP", :);

pan_angles_deg = frank_data.pan_angles_deg;
pan_order = sort(pan_angles_deg, 'descend');
listener_offsets_m = frank_data.listener_offset_m;
position_labels = ["centre", "off_centre"];
subjects = unique(trials.Participant, 'stable');
n_subjects = numel(subjects);
n_pan = numel(pan_order);
n_positions = numel(listener_offsets_m);
n_conditions = n_positions * n_pan;

avg_table = table('Size', [n_conditions, 6], ...
    'VariableTypes', {'double', 'double', 'double', 'string', 'double', 'double'}, ...
    'VariableNames', {'PanAngleDeg', 'ObjectiveDeg', 'LeftOffsetM', ...
    'PositionLabel', 'MeanSubjectiveDeg', 'StdSubjectiveDeg'});

avgResponseVector = zeros(n_conditions, 1);
stdResponseVector = zeros(n_conditions, 1);
trials_nested = nan(n_conditions, n_subjects, 2);
counts = zeros(n_conditions, n_subjects);

iCond = 0;
for iPos = 1:n_positions
    offset_m = listener_offsets_m(iPos);
    for iPan = 1:n_pan
        iCond = iCond + 1;
        pan_deg = pan_order(iPan);
        mask = trials.LeftOffsetM == offset_m & trials.PanAngleDeg == pan_deg;
        pose = frank2013_listener_pose(offset_m, frank_data.lsp_radius_m);
        resp = world_az_to_listener_az( ...
            trials.PercAngleDeg(mask), offset_m, 0, ...
            frank_data.lsp_radius_m, pose.listener_yaw_deg);
        avgResponseVector(iCond) = mean(resp, 'omitnan');
        stdResponseVector(iCond) = std(resp, 0, 'omitnan');

        avg_table.PanAngleDeg(iCond) = pan_deg;
        avg_table.ObjectiveDeg(iCond) = pan_deg;
        avg_table.LeftOffsetM(iCond) = offset_m;
        avg_table.PositionLabel(iCond) = position_labels(iPos);
        avg_table.MeanSubjectiveDeg(iCond) = avgResponseVector(iCond);
        avg_table.StdSubjectiveDeg(iCond) = stdResponseVector(iCond);

        for iSubj = 1:n_subjects
            subj_id = subjects(iSubj);
            subj_mask = mask & trials.Participant == subj_id;
            subj_vals = world_az_to_listener_az( ...
                trials.PercAngleDeg(subj_mask), offset_m, 0, ...
                frank_data.lsp_radius_m, pose.listener_yaw_deg);
            n_reps = numel(subj_vals);
            counts(iCond, iSubj) = n_reps;
            if n_reps > 0
                trials_nested(iCond, iSubj, 1:min(n_reps, 2)) = subj_vals(1:min(n_reps, 2));
            end
        end
    end
end

listexp_data = struct();
listexp_data.avgResponse = avg_table;
listexp_data.avgResponseVector = avgResponseVector;
listexp_data.stdResponseVector = stdResponseVector;
listexp_data.frank2013_lsp_az_deg = frank_data.lsp_az_deg;
listexp_data.frank2013_lsp_radius_m = frank_data.lsp_radius_m;
listexp_data.frank2013_presentation_lvl_dBA = 65;
listexp_data.r2_resample = struct('unit', 'nested', 'trials', trials_nested, 'counts', counts);
listexp_data.extended_re_meta = build_frank2013_re_meta(avg_table, frank_data.lsp_az_deg, ...
    frank_data.lsp_radius_m);
end

function re_meta = build_frank2013_re_meta(avg_table, lsp_az_deg, lsp_radius_m)
%BUILD_FRANK2013_RE_META Per-trial VBAP loudspeaker metadata for extended rE.
% Speaker azimuths are listener-relative in the room frame (0 = front axis).
% Head yaw for off-centre listeners is stored separately; Kurz subtracts it
% internally and Stitt passes it as rotAz then converts output to head frame.

speed_mps = 345;
n_trials = height(avg_table);

re_meta = repmat(struct('az_deg', [], 'distance_m', [], 'gain_lin', [], ...
    'delay_s', [], 'listener_yaw_deg', [], 'notes', ""), n_trials, 1);

for iTrial = 1:n_trials
    row = avg_table(iTrial, :);
    target_az = row.PanAngleDeg;
    vbap_gains = compute_vbap_gains_2d(target_az, lsp_az_deg);

    pose = frank2013_listener_pose(row.LeftOffsetM, lsp_radius_m);

    spk_lat = lsp_radius_m * sind(lsp_az_deg);
    spk_front = lsp_radius_m * cosd(lsp_az_deg);
    lis_lat = row.LeftOffsetM;
    lis_front = 0;
    dx_lat = spk_lat - lis_lat;
    dx_front = spk_front - lis_front;

    re_meta(iTrial).az_deg = atan2d(dx_lat, dx_front);
    re_meta(iTrial).distance_m = hypot(dx_lat, dx_front);
    re_meta(iTrial).gain_lin = vbap_gains;
    re_meta(iTrial).delay_s = re_meta(iTrial).distance_m / speed_mps;
    re_meta(iTrial).listener_yaw_deg = pose.listener_yaw_deg;
    re_meta(iTrial).notes = sprintf('frank2013 VBAP pan %.3f deg, offset %.2f m', ...
        target_az, row.LeftOffsetM);
end
end

function re_meta = build_ramirez2024_re_meta(vbap_only_az_deg, lsp_az_deg_paper)
%BUILD_RAMIREZ2024_RE_META Per-trial loudspeaker VBAP metadata for extended rE.

lsp_radius_m = 1;
speed_mps = 345;
n_trials = numel(vbap_only_az_deg);
lsp_az_codebase = sort(-lsp_az_deg_paper);

spk_x = lsp_radius_m * cosd(lsp_az_codebase);
spk_y = lsp_radius_m * sind(lsp_az_codebase);

re_meta = repmat(struct('az_deg', [], 'distance_m', [], 'gain_lin', [], ...
    'delay_s', [], 'notes', ""), n_trials, 1);

for iTrial = 1:n_trials
    target_az = -vbap_only_az_deg(iTrial);
    vbap_gains = compute_vbap_gains_2d(target_az, lsp_az_codebase);

    re_meta(iTrial).az_deg = atan2d(spk_y, spk_x);
    re_meta(iTrial).distance_m = hypot(spk_x, spk_y);
    re_meta(iTrial).gain_lin = vbap_gains;
    re_meta(iTrial).delay_s = re_meta(iTrial).distance_m / speed_mps;
    re_meta(iTrial).notes = sprintf('ramirez2024 VBAP target %.0f deg (paper azimuth)', target_az);
end
end

function re_meta = build_llado2026_re_meta(exp_table)
%BUILD_LLADO2026_RE_META Per-trial loudspeaker geometry for the extended-rE models.
% Two loudspeakers at +/-30 deg on a 2 m radius. Cartesian frame is x = front,
% y = left. Listener positions: P0 centre, P1 0.25 m left, P2 0.5 m left,
% P3 1.0 m left. Table ICLD is positive toward the right (right channel
% louder); ICTD is left relative to right in ms (negative = left earlier).

speaker_radius_m = 2;
speaker_span_deg = 60;
speed_mps = 345;
left_az = +speaker_span_deg / 2;
right_az = -speaker_span_deg / 2;
spk_x = [speaker_radius_m * cosd(left_az), speaker_radius_m * cosd(right_az)];
spk_y = [speaker_radius_m * sind(left_az), speaker_radius_m * sind(right_az)];

% Positive y is left, matching desena2013 / frank2013.
position_label_to_listener_y_m = struct('P0', 0, 'P1', 0.25, 'P2', 0.5, 'P3', 1.0);
n_trials = height(exp_table);
re_meta = repmat(struct('az_deg', [], 'distance_m', [], 'gain_lin', [], ...
    'delay_s', [], 'notes', ""), n_trials, 1);

for iTrial = 1:n_trials
    row = exp_table(iTrial, :);
    pos_label = char(string(row.PositionLabel));
    if ~isfield(position_label_to_listener_y_m, pos_label)
        error('llado2026: unknown PositionLabel %s at trial %d.', pos_label, iTrial);
    end

    lis_y = position_label_to_listener_y_m.(pos_label);
    dx = spk_x - 0;
    dy = spk_y - lis_y;

    icld_db = row.ICLD;
    ictd_s = row.ICTD / 1000; % left relative to right; negative = left earlier

    re_meta(iTrial).az_deg = atan2d(dy, dx);
    re_meta(iTrial).distance_m = hypot(dx, dy);
    % Positive ICLD boosts the right loudspeaker (P0 sweep is perceived right).
    re_meta(iTrial).gain_lin = [1, db2mag(icld_db)]; % left, right
    % delay_s = ICTD plus geometric propagation (r/c). Negative ICTD leads the
    % left channel. Stitt strips r/c before enervecExt.
    re_meta(iTrial).delay_s = [ictd_s, 0] + re_meta(iTrial).distance_m / speed_mps;
    re_meta(iTrial).notes = sprintf( ...
        'llado2026 %s (%.2f m left), ICTD=%g ms, ICLD=%g dB', ...
        pos_label, lis_y, row.ICTD, row.ICLD);
end
end
