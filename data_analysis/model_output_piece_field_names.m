function field_names = model_output_piece_field_names(model_id)
%MODEL_OUTPUT_PIECE_FIELD_NAMES Workspace fields stored for one model cache piece.
model_id = char(model_id);

switch model_id
    case 'lindemann1986'
        field_names = {'est_angle_lindemann1986', 'error_lindemann1986', 'time_lindemann1986_s'};
    case 'breebaart2001'
        field_names = {'est_angle_breebaart2001', 'error_breebaart2001', 'time_breebaart2001_s'};
    case 'faller2004'
        field_names = {'est_angle_faller2004', 'error_faller2004', 'time_faller2004_s'};
    case 'may2011'
        field_names = {'est_angle_may2011', 'error_may2011', 'time_may2011_s'};
    case 'dietz2011'
        field_names = {'est_angle_dietz2011', 'error_dietz2011', 'time_dietz2011_s'};
    case 'takanen2013'
        field_names = {'est_angle_takanen2013', 'error_takanen2013', 'time_takanen2013_s'};
    case 'llado2025'
        field_names = {'est_angle_llado2025', 'error_llado2025', 'time_llado2025_s'};
    case 'kurz2017'
        field_names = {'est_angle_kurz2017', 'error_kurz2017', 'time_kurz2017_s'};
    case 'stitt2016'
        field_names = {'est_angle_stitt2016', 'error_stitt2016', 'time_stitt2016_s'};
    case 'rE'
        field_names = {'est_angle_rE', 'error_rE', 'time_rE_s'};
    case 'saddler2024'
        field_names = { ...
            'est_angle_expected_saddler2024', 'error_saddler2024', 'time_saddler2024_s', ...
            'est_angle_saddler2024', 'est_class_index_saddler2024', ...
            'est_angle_saddler2024_per_model', ...
            'est_angle_expected_saddler2024_per_model', ...
            'est_class_index_saddler2024_per_model'};
    case 'wang2026'
        field_names = {'est_angle_wang2026', 'error_wang2026', 'time_wang2026_s'};
    case 'vecchiotti2019'
        field_names = { ...
            'est_angle_vecchiotti2019', 'error_vecchiotti2019', 'time_vecchiotti2019_s', ...
            'est_angle_expected_vecchiotti2019', 'est_class_index_vecchiotti2019', ...
            'est_angle_raw_vecchiotti2019', 'vecchiotti_max_prob', 'vecchiotti_prob_entropy'};
    otherwise
        error('model_output_piece_field_names:UnknownModel', ...
            'Unknown model id: %s', model_id);
end
end
