function filter_meta = re_compute_desena2013_lsp_filter_metadata()
% Precompute per-trial loudspeaker gain/delay metadata for desena2013.
% Output shape: [4 x 8] over (rendering_idx, target_angle_idx).
% Each element contains:
%   gain_lin      [1x5] RMS energy per loudspeaker filter
%   delay_samples [1x5] sample index of abs-peak (zero-based)

data_dir = fullfile('aux_data', 'DeSena2013', 'output_files_desena2013');
cache_file = fullfile('aux_data', 'DeSena2013', 'desena2013_filter_metadata.mat');

if isfile(cache_file)
    cache_info = dir(cache_file);
    data_files = dir(fullfile(data_dir, '*.txt'));
    if ~isempty(data_files)
        newest_data_datenum = max([data_files.datenum]);
        if cache_info.datenum >= newest_data_datenum
            cache_data = load(cache_file, 'filter_meta');
            if isfield(cache_data, 'filter_meta')
                filter_meta = cache_data.filter_meta;
                return;
            end
        end
    end
end

n_rendering = 4;
n_target_angles = 8;
n_lsp = 5;
filter_meta = repmat(struct('gain_lin', zeros(1, n_lsp), ...
                            'delay_samples', zeros(1, n_lsp)), ...
                     n_rendering, n_target_angles);

for rendering_idx = 1:n_rendering
    surround_id = rendering_idx - 1;
    for target_angle_idx = 1:n_target_angles
        target_angle_id = target_angle_idx - 1;
        gains = zeros(1, n_lsp);
        delays = zeros(1, n_lsp);

        for lsp_idx = 1:n_lsp
            lsp_id = lsp_idx - 1;
            file_name = sprintf('%d_%d_%d.txt', target_angle_id, surround_id, lsp_id);
            file_path = fullfile(data_dir, file_name);
            h = load(file_path);
            h = h(:);

            gains(lsp_idx) = sqrt(sum(h.^2));
            [~, peak_idx] = max(abs(h));
            delays(lsp_idx) = peak_idx - 1; % zero-based sample delay
        end

        filter_meta(rendering_idx, target_angle_idx).gain_lin = gains;
        filter_meta(rendering_idx, target_angle_idx).delay_samples = delays;
    end
end

save(cache_file, 'filter_meta');
end
