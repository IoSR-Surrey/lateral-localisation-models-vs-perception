function dest_path = download_frank2013()
%DOWNLOAD_FRANK2013 Download the Frank (2013) localisation raw data file.
%
%   dest_path = DOWNLOAD_FRANK2013() fetches frankPhD2013lococ.txt from the
%   IEM listening-experiment open data repository into aux_data/frank2013/
%   (next to this file), where read_frank2013_lococ expects it. Existing
%   files are not re-downloaded.
%
%   Source: Institute of Electronic Music and Acoustics (IEM), Graz,
%   "Listening experiment data" (ListExData),
%   https://opendata.iem.at/projects/listening_experiment_data/
%   Data from M. Frank, "Phantom Sources using Multiple Loudspeakers in the
%   Horizontal Plane", PhD thesis, University of Music and Performing Arts
%   Graz, 2013.

this_dir = fileparts(mfilename('fullpath'));
dest_path = fullfile(this_dir, 'frankPhD2013lococ.txt');
url = 'https://opendata.iem.at/projects/listening_experiment_data/frankPhD2013lococ.txt';

if isfile(dest_path)
    fprintf('Skip (exists): %s\n', dest_path);
    return
end

fprintf('Downloading %s ...\n', url);
try
    websave(dest_path, url);
catch err
    if isfile(dest_path)
        delete(dest_path);
    end
    error('download_frank2013:DownloadFailed', ...
        'Failed to download %s (%s). Download it manually from %s and place it in %s.', ...
        url, err.message, 'https://opendata.iem.at/projects/listening_experiment_data/', this_dir);
end
fprintf('Saved: %s\n', dest_path);
end
