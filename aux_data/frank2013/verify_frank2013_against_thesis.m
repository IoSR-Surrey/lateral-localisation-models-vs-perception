function all_passed = verify_frank2013_against_thesis()
%VERIFY_FRANK2013_AGAINST_THESIS Check imported data against Frank thesis tables.
%
%   all_passed = VERIFY_FRANK2013_AGAINST_THESIS() compares centre-position
%   localization statistics to Table 4 (median deviation from ideal curve)
%   and Table 5 (mean 95% confidence interval width) in Frank (2013/2014).

this_dir = fileparts(mfilename('fullpath'));
addpath(this_dir);
frank_data = read_frank2013_lococ();
trials = frank_data.trials;
trials = trials(trials.LeftOffsetM == 0, :);

pan_angles_deg = frank_data.pan_angles_deg;
method_keys = frank_data.method_keys;
method_labels = frank_data.method_labels;

n_participants = numel(unique(trials.Participant));
n_pan = numel(pan_angles_deg);
fprintf('Centre position: %d participants, %d pan angles\n\n', n_participants, n_pan);

assert(n_participants == 14, 'Expected 14 participants, got %d.', n_participants);
assert(n_pan == 9, 'Expected 9 pan angles, got %d.', n_pan);

table4_paper = [2.35, 1.28, 1.05, 1.58];
table5_paper = [2.75, 3.06, 3.48, 3.53];
table4_tol = 0.05;
table5_tol = 0.05;

all_passed = true;
summary = {};

for im = 1:numel(method_keys)
    method = method_keys{im};
    method_trials = trials(trials.Method == method, :);
    deviations = nan(n_pan, 1);
    ci_widths = nan(n_pan, 1);

    for ip = 1:n_pan
        pan_deg = pan_angles_deg(ip);
        mask = method_trials.PanAngleDeg == pan_deg;
        resp = method_trials.PercAngleDeg(mask);
        assert(numel(resp) == 28, '%s pan %.3f: expected 28 trials, got %d.', ...
            method, pan_deg, numel(resp));

        median_perc = median(resp, 'omitnan');
        deviations(ip) = abs(median_perc - pan_deg);
        ci_widths(ip) = frank2013_median_ci_width(resp(~isnan(resp)));
    end

    table4_val = mean(deviations, 'omitnan');
    table5_val = mean(ci_widths, 'omitnan');

    pass4 = abs(table4_val - table4_paper(im)) <= table4_tol;
    pass5 = abs(table5_val - table5_paper(im)) <= table5_tol;
    passed = pass4 && pass5;
    all_passed = all_passed && passed;

    summary(end + 1, :) = {method_labels{im}, table4_val, table4_paper(im), pass4, ...
        table5_val, table5_paper(im), pass5, passed}; %#ok<AGROW>
end

T = cell2table(summary, 'VariableNames', { ...
    'Method', 'Table4Computed', 'Table4Paper', 'Table4Pass', ...
    'Table5Computed', 'Table5Paper', 'Table5Pass', 'AllPass'});
disp('Table 4: average |median(perceived) - pan angle| over directions');
disp('Table 5: mean IQR-based 95% CI width (Frank CI2-style) over directions');
disp(T);

if ~all_passed
    error('verify_frank2013_against_thesis: one or more thesis checks failed.');
end
fprintf('\nAll thesis table checks passed.\n');
end

function ci_width = frank2013_median_ci_width(values)
%FRANK2013_MEDIAN_CI_WIDTH IQR-based 95% CI width for the median (IEM CI2-style).

values = values(:);
values = values(~isnan(values));
n = numel(values);
if n < 2
    ci_width = NaN;
    return;
end

iqr = prctile(values, 75) - prctile(values, 25);
ci_width = 2 * 1.57 * iqr / sqrt(n) * tinv(0.975, n - 1) / 1.96;
end
