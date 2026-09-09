function label = format_model_plot_label(model_id)
%FORMAT_MODEL_PLOT_LABEL Display label for a model id in figures and tables.
%
%   label = FORMAT_MODEL_PLOT_LABEL(model_id) returns the string shown in
%   plot titles and axis tick labels. Extended energy-vector models include
%   an "(rE)" suffix for clarity.

model_id = char(string(model_id));

switch model_id
    case 'rE'
        label = 'rE-gerzon1992';
    case {'kurz2017', 'extended_re'}
        label = 'rE-kurz2017';
    case {'stitt2016', 'extended_rE_Stitt'}
        label = 'rE-stitt2016';
    case {'vecchiotti2019', 'waveloc'}
        label = 'vecchiotti2019';
    otherwise
        label = model_id;
end
end
