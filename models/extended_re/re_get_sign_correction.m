function sign_correction = re_get_sign_correction(listexp_data_id)
% Return scalar sign applied to extended rE azimuth estimates so they match
% listexp_data.avgResponseVector for each experiment.
%
% Positive avgResponseVector = left for simon2010 and llado2026.
% desena2013 avgResponseVector is negated relative to stimulus angle.

switch listexp_data_id
    case 'desena2013'
        sign_correction = +1;
    case 'simon2010'
        % avgResponseVector = avgResponse(:,5); positive = left.
        sign_correction = +1;
    case 'llado2026'
        % MeanLatDeg and rE atan2 both use positive = left.
        sign_correction = +1;
    case 'ramirez2024'
        sign_correction = +1;
    case 'frank2013'
        sign_correction = +1;
    otherwise
        sign_correction = -1;
end
end
