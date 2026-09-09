function bin_signal = generate_stimuli(authoryear, sofa_file, listexp_data, presentation_lvl, stim_opts)
%GENERATE_STIMULI Generate binaural stimuli for a listening experiment.
%
%   bin_signal = GENERATE_STIMULI(authoryear, sofa_file, listexp_data,
%   presentation_lvl) returns a cell array of [nSamples x 2] binaural signals
%   (column 1 = left ear, column 2 = right ear; positive lateral angle = left)
%   reproducing the stimuli of the requested experiment.
%
%   Inputs
%       authoryear        Dataset id: 'desena2013', 'simon2010',
%                         'llado2026', 'ramirez2024', or 'frank2013'.
%       sofa_file         Loaded SOFA HRTF object.
%       listexp_data      Perceptual-data struct (from load_listexp_data),
%                         used to drive the per-trial conditions (simon2010,
%                         llado2026, ramirez2024, frank2013).
%       presentation_lvl  Target presentation level in dB SPL. Pass NaN (or
%                         omit) to skip level calibration (gain = 1).
%       stim_opts         Optional struct with dataset-specific stimulus
%                         options. For frank2013:
%                           frank2013_single_burst  When true, use one
%                           400 ms burst instead of three with inter-burst
%                           silence (default false).
%
%   Each dataset's noise is drawn with the RNG state set by the caller, so the
%   stimuli are reproducible for a fixed seed.

if nargin < 4 || isempty(presentation_lvl)
    presentation_lvl = NaN;
end
if nargin < 5 || isempty(stim_opts)
    stim_opts = struct();
end
frank2013_single_burst = isfield(stim_opts, 'frank2013_single_burst') ...
    && stim_opts.frank2013_single_burst;

switch authoryear
    case 'desena2013'
        bin_signal = generate_desena2013(sofa_file, presentation_lvl);
    case 'simon2010'
        bin_signal = generate_simon2010(sofa_file, listexp_data, presentation_lvl);
    case 'llado2026'
        bin_signal = generate_llado2026(listexp_data, presentation_lvl);
    case 'ramirez2024'
        bin_signal = generate_ramirez2024(sofa_file, listexp_data, presentation_lvl);
    case 'frank2013'
        bin_signal = generate_frank2013(sofa_file, listexp_data, presentation_lvl, ...
            frank2013_single_burst);
    otherwise
        bin_signal = [];
end
end

function bin_signal = generate_desena2013(obj, presentation_lvl)
%GENERATE_DESENA2013 Multichannel surround stimuli convolved through HRTFs.
% Loudspeaker signals (4 rendering methods x 8 target angles x 5 speakers)
% are loaded from text files, binauralised for two listener positions, and
% convolved with a Tukey-windowed noise burst. Saved rendering filters are
% at 44100 Hz; the SOFA HRTF is resampled to that rate when needed.

% Saved De Sena loudspeaker filters (aux_data/DeSena2013/output_files_desena2013/)
% are at 44100 Hz — use that rate regardless of the SOFA's native SamplingRate.
fs = 44100;
if obj.Data.SamplingRate ~= fs
    obj = SOFAresample(obj, fs);
end
LSP_distance = 2;                      % loudspeaker distance in m
LSP_angles = 180:-360/5:-179;          % five-speaker ring angles in deg
listener_positions = [0 0; 135 0.3];   % [angle(deg) distance(m)]

% Noise burst with a 30% Tukey taper (100 ms).
noise = randn(round(fs / 10), 1) .* tukeywin(round(fs / 10), 0.3);

nLisPos = size(listener_positions, 1);
nSurround = 4;
nAngles = 8;
nSpeakers = 5;
first_sample = 6850;
last_sample = 11550;

lsp_dir = "aux_data/DeSena2013/output_files_desena2013/";
bin_signal_cut = cell(nLisPos, nSurround, nAngles);
for iLisPos = 1:nLisPos
    for surround_id = 1:nSurround
        for target_angle_id = 1:nAngles
            lsp_signal = zeros(nSpeakers, 0);
            for lsp_number = 1:nSpeakers
                lsp_file = lsp_dir + num2str(target_angle_id - 1) + "_" + ...
                    num2str(surround_id - 1) + "_" + num2str(lsp_number - 1) + ".txt";
                sig = load(lsp_file);
                lsp_signal(lsp_number, 1:numel(sig)) = sig(:)';
            end

            bin_IR = func_binauralise_lsp_signals(lsp_signal, LSP_angles, ...
                LSP_distance, obj, fs, ...
                'listener_angle', listener_positions(iLisPos, 1), ...
                'listener_distance', listener_positions(iLisPos, 2));

            bin_full = [conv(bin_IR(:, 1), noise), conv(bin_IR(:, 2), noise)];
            bin_signal_cut{iLisPos, surround_id, target_angle_id} = ...
                bin_full(first_sample:last_sample, :);
        end
    end
end

% Calibrate the level using the central listener position (1), ID rendering
% (4), left ear of target angle 4. The reference level is arbitrary, so the
% exact channel only needs to be in the right ballpark.
norm_factor_l = 1;
if ~isnan(presentation_lvl)
    cal_bin_signal_l = scaletodbspl(bin_signal_cut{1, 4, 4}(:, 1), presentation_lvl);
    norm_factor_l = rms(cal_bin_signal_l) / rms(bin_signal_cut{1, 3, 4}(:, 1));
end

% Flatten with ordering: method (fastest), angle, listener position (slowest),
% matching load_listexp_data's avgResponseVector for desena2013.
bin_signal = cell(nLisPos * nAngles * nSurround, 1);
jj = 1;
for i_listpos = 1:nLisPos
    for i_lspangle = 1:nAngles
        for i_renderingmethod = 1:nSurround
            bin_signal{jj} = bin_signal_cut{i_listpos, i_renderingmethod, i_lspangle} * norm_factor_l;
            jj = jj + 1;
        end
    end
end
end

function bin_signal = generate_simon2010(obj, listexp_data, presentation_lvl)
%GENERATE_SIMON2010 Two-loudspeaker stimuli with inter-channel level/time differences.
% Each trial sums two HRTF-convolved noise bursts; the second is delayed by
% the inter-channel time difference (ICTD) and scaled by the level difference
% (ICLD).

fs = obj.Data.SamplingRate;

% Noise burst with raised-cosine on/off ramps and short leading/trailing silence.
noise = [zeros(round(fs / 1000), 1); randn(fs / 5, 1); zeros(round(fs / 1000), 1)];
w = cos(2 * pi * 5 * (1 / fs:1 / fs:1 / 20)').^2;
noise(1:length(w)) = noise(1:length(w)) .* w(end:-1:1);
noise(end - length(w) + 1:end) = noise(end - length(w) + 1:end) .* w;

nTrials = size(listexp_data.avgResponse, 1);
bin_input = cell(nTrials, 1);
norm_factor_l = 1;
for iTrial = 1:nTrials
    lsp_angle_id(1) = SOFAfind(obj, listexp_data.avgResponse(iTrial, 3), 0);
    lsp_angle_id(2) = SOFAfind(obj, listexp_data.avgResponse(iTrial, 4), 0);

    input_from_each_lsp = zeros(2, 2, numel(noise) + size(obj.Data.IR, 3) - 1);
    for iLsp = 1:2
        input_from_each_lsp(iLsp, 1, :) = conv(noise, squeeze(obj.Data.IR(lsp_angle_id(iLsp), 1, :)));
        input_from_each_lsp(iLsp, 2, :) = conv(noise, squeeze(obj.Data.IR(lsp_angle_id(iLsp), 2, :)));
    end

    ICLD = listexp_data.avgResponse(iTrial, 1);
    ICTD = round(listexp_data.avgResponse(iTrial, 2) / 1000 * fs);

    % Delay and scale the second loudspeaker relative to the first.
    input_from_each_lsp_delayed = input_from_each_lsp;
    if ICTD > 0
        input_from_each_lsp_delayed(2, :, :) = ...
            [squeeze(input_from_each_lsp(2, :, ICTD + 1:end)), zeros(2, ICTD)] * db2mag(ICLD);
    else
        input_from_each_lsp_delayed(2, :, :) = ...
            [zeros(2, -ICTD), squeeze(input_from_each_lsp(2, :, 1:end + ICTD))] * db2mag(ICLD);
    end
    % Column 1 = left ear, column 2 = right ear (positive = left).
    bin_input{iTrial} = squeeze(sum(input_from_each_lsp_delayed, 1))';

    % Calibrate the left-ear level for the [0 45] layout with ICTD == 0,
    % ICLD == -18 (front loudspeaker only).
    if ~isnan(presentation_lvl) && ICTD == 0 && ICLD == -18 && listexp_data.avgResponse(iTrial, 3) == 0
        cal_bin_signal_l = scaletodbspl(bin_input{iTrial}(:, 1), presentation_lvl);
        norm_factor_l = rms(cal_bin_signal_l) / rms(bin_input{iTrial}(:, 1));
    end
end

bin_signal = cell(nTrials, 1);
for i = 1:nTrials
    bin_signal{i} = bin_input{i} * norm_factor_l;
end
end

function bin_signal = generate_llado2026(listexp_data, presentation_lvl)
%GENERATE_LLADO2026 Load pre-rendered KEMAR binaural WAV stimuli.
% One WAV file per condition, keyed by listener position and ICTD/ICLD from
% listexp_data.avgResponse.
% Stimuli were recorded at 48000 Hz (see evaluate_models_for_hrtf).

if ~isfield(listexp_data, 'avgResponse') || ~istable(listexp_data.avgResponse)
    error('llado2026: listexp_data.avgResponse table is required.');
end
exp_table = listexp_data.avgResponse;
needed = {'PositionLabel', 'ICTD', 'ICLD'};
if ~all(ismember(needed, exp_table.Properties.VariableNames))
    error('llado2026: avgResponse must include PositionLabel, ICTD, and ICLD.');
end

stim_folder = fullfile("aux_data", "llado2026", "stimuli_KEMAR", "wavfiles");

nTrials = height(exp_table);
bin_signal = cell(nTrials, 1);
norm_factor_l = 1;
for iFile = 1:nTrials
    wav_file = stim_folder + "/" + exp_table.PositionLabel(iFile) + ...
        "_ICTD_" + exp_table.ICTD(iFile) + "_ICLD_" + exp_table.ICLD(iFile) + ".wav";
    bin_signal{iFile} = audioread(wav_file);

    % Calibrate the left-ear level at the central position (P0) with zero
    % ICTD/ICLD.
    if ~isnan(presentation_lvl) && strcmp(exp_table.PositionLabel(iFile), "P0") && ...
            exp_table.ICTD(iFile) == 0 && exp_table.ICLD(iFile) == 0
        cal_bin_signal_l = scaletodbspl(bin_signal{iFile}(:, 1), presentation_lvl);
        norm_factor_l = rms(cal_bin_signal_l) / rms(bin_signal{iFile}(:, 1));
    end
end

if ~isnan(presentation_lvl)
    if norm_factor_l == 1 && ~any(string(exp_table.PositionLabel) == "P0" ...
            & exp_table.ICTD == 0 & exp_table.ICLD == 0)
        warning('llado2026: P0 ICTD=0 ICLD=0 condition not found; skipping level calibration.');
    else
        for i = 1:nTrials
            bin_signal{i} = bin_signal{i} * norm_factor_l;
        end
    end
end
end

function bin_signal = generate_ramirez2024(obj, listexp_data, presentation_lvl)
%GENERATE_RAMIREZ2024 C1 loudspeaker stimuli via pair VBAP and HRTF binauralisation.
% 300 ms broadband noise with 10 ms cosine-squared ramps (Ramírez et al., 2024).

fs = obj.Data.SamplingRate;
lsp_az_paper = listexp_data.ramirez2024_lsp_az_deg;
lsp_az_deg = sort(-lsp_az_paper); % paper (neg=left) -> sorted codebase (pos=left)
lsp_distance_m = 1;
n_lsp = numel(lsp_az_deg);

n_samples = round(0.3 * fs);
ramp_samples = round(0.01 * fs);
noise = randn(n_samples, 1);
ramp = cos(linspace(-pi / 2, pi / 2, ramp_samples)).^2;
noise(1:ramp_samples) = noise(1:ramp_samples) .* ramp';
noise(end - ramp_samples + 1:end) = noise(end - ramp_samples + 1:end) .* ramp(end:-1:1)';

objective_deg = listexp_data.avgResponse.ObjectiveDeg;
n_trials = numel(objective_deg);
bin_signal = cell(n_trials, 1);
norm_factor_l = 1;
cal_ref_deg = 5;

for iTrial = 1:n_trials
    target_az_paper = objective_deg(iTrial);
    target_az = -target_az_paper;
    vbap_gains = compute_vbap_gains_2d(target_az, lsp_az_deg);

    lsp_signal = zeros(n_lsp, numel(noise));
    for iLsp = 1:n_lsp
        lsp_signal(iLsp, :) = vbap_gains(iLsp) * noise';
    end

    bin_ir = func_binauralise_lsp_signals(lsp_signal, lsp_az_deg, ...
        lsp_distance_m, obj, fs);
    bin_signal{iTrial} = bin_ir;

    if ~isnan(presentation_lvl) && target_az_paper == cal_ref_deg
        cal_bin_signal_l = scaletodbspl(bin_signal{iTrial}(:, 1), presentation_lvl);
        norm_factor_l = rms(cal_bin_signal_l) / rms(bin_signal{iTrial}(:, 1));
    end
end

if ~isnan(presentation_lvl)
    for i = 1:n_trials
        bin_signal{i} = bin_signal{i} * norm_factor_l;
    end
end
end

function bin_signal = generate_frank2013(obj, listexp_data, presentation_lvl, single_burst)
%GENERATE_FRANK2013 VBAP stimuli on an 8-loudspeaker ring (Frank, 2013).
% Pink-noise bursts (100 ms fade-in, 200 ms steady, 100 ms fade-out) are
% binauralised for centre or off-centre listener. By default, three bursts
% are played with 200 ms inter-burst silence; set single_burst true for one
% burst only (400 ms total).

if nargin < 4 || isempty(single_burst)
    single_burst = false;
end

fs = obj.Data.SamplingRate;
lsp_az_deg = listexp_data.frank2013_lsp_az_deg;
lsp_radius_m = listexp_data.frank2013_lsp_radius_m;
n_lsp = numel(lsp_az_deg);

frank_dir = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'aux_data', 'frank2013');
addpath(frank_dir);

fade_in_s = 0.1;
hold_s = 0.2;
fade_out_s = 0.1;
silence_s = 0.2;
if single_burst
    n_bursts = 1;
else
    n_bursts = 3;
end

fade_in_n = round(fade_in_s * fs);
fade_out_n = round(fade_out_s * fs);
burst_samples = round((fade_in_s + hold_s + fade_out_s) * fs);
silence_samples = round(silence_s * fs);
if single_burst
    n_samples = burst_samples;
else
    n_samples = n_bursts * burst_samples + (n_bursts - 1) * silence_samples;
end

ramp_in = hann(2 * fade_in_n);
ramp_in = ramp_in(1:fade_in_n);
ramp_out = hann(2 * fade_out_n);
ramp_out = ramp_out(end - fade_out_n + 1:end);

pan_deg = listexp_data.avgResponse.PanAngleDeg;
left_offset_m = listexp_data.avgResponse.LeftOffsetM;
n_trials = numel(pan_deg);
bin_signal = cell(n_trials, 1);
norm_factor_l = 1;

for iTrial = 1:n_trials
    noise_burst = pinknoise(burst_samples);
    env = ones(burst_samples, 1);
    env(1:fade_in_n) = ramp_in;
    env(end - fade_out_n + 1:end) = ramp_out;
    noise_burst = noise_burst .* env;

    stimulus = zeros(n_samples, 1);
    idx = 1;
    for iBurst = 1:n_bursts
        stimulus(idx:idx + burst_samples - 1) = noise_burst;
        idx = idx + burst_samples + silence_samples;
    end

    target_az = pan_deg(iTrial);
    pose = frank2013_listener_pose(left_offset_m(iTrial), lsp_radius_m);
    vbap_gains = compute_vbap_gains_2d(target_az, lsp_az_deg);
    lsp_signal = zeros(n_lsp, n_samples);
    for iLsp = 1:n_lsp
        lsp_signal(iLsp, :) = vbap_gains(iLsp) * stimulus';
    end

    bin_out = func_binauralise_lsp_signals(lsp_signal, lsp_az_deg, lsp_radius_m, obj, fs, ...
        'lis_pos_cart', pose.lis_pos_cart, ...
        'listener_orientation', pose.listener_orientation);
    bin_signal{iTrial} = bin_out;

    if ~isnan(presentation_lvl) && left_offset_m(iTrial) == 0 && target_az == 0
        cal_bin_signal_l = scaletodbspl(bin_signal{iTrial}(:, 1), presentation_lvl);
        norm_factor_l = rms(cal_bin_signal_l) / rms(bin_signal{iTrial}(:, 1));
    end
end

if ~isnan(presentation_lvl)
    for i = 1:n_trials
        bin_signal{i} = bin_signal{i} * norm_factor_l;
    end
end
end
