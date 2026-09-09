function data = read_frank2013_lococ()
%READ_FRANK2013_LOCOC Load Frank (2013) localization experiment trial table.
%
%   data = READ_FRANK2013_LOCOC() reads frankPhD2013lococ.txt and returns a
%   struct with the trial table and experiment constants.
%
%   Azimuth convention: 0 = front, positive = left (codebase convention).

this_dir = fileparts(mfilename('fullpath'));
txt_file = fullfile(this_dir, 'frankPhD2013lococ.txt');
if ~isfile(txt_file)
    error('read_frank2013_lococ: missing %s', txt_file);
end

fid = fopen(txt_file, 'r');
if fid < 0
    error('read_frank2013_lococ: could not open %s', txt_file);
end
cleanup = onCleanup(@() fclose(fid));
header_line = fgetl(fid);
if ~ischar(header_line)
    error('read_frank2013_lococ: empty file %s', txt_file);
end

parsed = textscan(fid, '%f %f %f %s %f', 'Delimiter', ' ', ...
    'MultipleDelimsAsOne', true, 'CollectOutput', false);
perc_angle = parsed{1};
pan_angle = parsed{2};
left_offset = parsed{3};
method = string(parsed{4});
participant = parsed{5};

trials = table();
trials.PercAngleDeg = perc_angle;
trials.PanAngleDeg = pan_angle;
trials.LeftOffsetM = left_offset;
trials.Method = method;
trials.Participant = participant;

valid_mask = ~isnan(trials.PanAngleDeg) & ~isnan(trials.Participant);
trials = trials(valid_mask, :);

data = struct();
data.trials = trials;
data.pan_angles_deg = sort(unique(trials.PanAngleDeg), 'ascend');
data.lsp_az_deg = [-135 -90 -45 0 45 90 135 180];
data.lsp_radius_m = 2.5;
data.listener_offset_m = [0, 1.25];
data.method_map = struct( ...
    'VBAP', 'VBAP', ...
    'MDAP', 'MDAP', ...
    'max_r_E', 'Ambi^rE', ...
    'basic', 'Ambi^rV');
data.method_keys = {'VBAP', 'MDAP', 'max-r_E', 'basic'};
data.method_labels = {'VBAP', 'MDAP', 'Ambi^rE', 'Ambi^rV'};
end
