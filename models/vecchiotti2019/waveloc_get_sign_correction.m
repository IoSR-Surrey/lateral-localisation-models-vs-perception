function sign_correction = waveloc_get_sign_correction(listexp_data_id)
%WAVELOC_GET_SIGN_CORRECTION Sign applied to WaveLoc azimuth outputs per dataset.
%
%   WaveLoc reports azimuth in its native convention (class index maps to
%   degrees via (index - 18) * 5). Perceptual avgResponseVector uses
%   positive = left for simon2010, llado2026, ramirez2024, and frank2013.
%
%   Default is -1 (negate raw WaveLoc azimuth) for all supported datasets.
%   Override per dataset here after validating on known-left/right trials.

switch listexp_data_id
    case {'desena2013', 'simon2010', 'llado2026', 'ramirez2024', 'frank2013'}
        sign_correction = -1;
    otherwise
        sign_correction = -1;
end
end
