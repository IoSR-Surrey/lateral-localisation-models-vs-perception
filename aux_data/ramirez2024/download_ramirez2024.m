function dest_path = download_ramirez2024()
%download_ramirez2024 - Download the Ramírez 2024 Table S2 xlsx
%   DEST_PATH = download_ramirez2024() fetches the Table S2 experimental
%   raw data xlsx from Zenodo into aux_data/ramirez2024 (next to this
%   file), where convert_ramirez2024_xlsx_to_mat expects it. Existing
%   files are not re-downloaded.
%
%   See also convert_ramirez2024_xlsx_to_mat, download_frank2013,
%   verify_ramirez2024_against_paper
%
%   Note: Run convert_ramirez2024_xlsx_to_mat after the first download

this_dir = fileparts(mfilename('fullpath'));
xlsx_name = 'Table S2_Data_Experimental raw data.xlsx';
dest_path = fullfile(this_dir, xlsx_name);
url = ['https://zenodo.org/api/records/10655341/files/' ...
    'Table%20S2_Data_Experimental%20raw%20data.xlsx/content'];
record_url = 'https://doi.org/10.5281/zenodo.10655341';

if isfile(dest_path)
    fprintf('Skip (exists): %s\n', dest_path);
    return
end

fprintf('Downloading %s ...\n', url);
if ~download_one_file(url, dest_path)
    error('download_ramirez2024:DownloadFailed', ...
        ['Failed to download %s. Download Table S2_Data_Experimental ' ...
        'raw data.xlsx manually from %s and place it in %s.'], ...
        url, record_url, this_dir);
end
fprintf('Saved: %s\n', dest_path);
end

function ok = download_one_file(url, dest_path)
try
    websave(dest_path, url, weboptions(Timeout=120));
    ok = is_xlsx_file(dest_path);
catch
    ok = false;
end
if ok
    return
end
if isfile(dest_path)
    delete(dest_path);
end
% Fallback to curl when MATLAB cannot validate the server certificate.
cmd = sprintf('curl -f -L -o "%s" "%s"', dest_path, url);
status = system(cmd);
ok = status == 0 && is_xlsx_file(dest_path);
if ~ok && isfile(dest_path)
    delete(dest_path);
end
end

function tf = is_xlsx_file(file_path)
tf = false;
if ~isfile(file_path)
    return
end
fid = fopen(file_path, 'r');
if fid < 0
    return
end
magic = fread(fid, 2, '*uint8');
fclose(fid);
% xlsx is a ZIP archive (PK). Reject HTML error pages saved by websave.
tf = numel(magic) == 2 && magic(1) == 80 && magic(2) == 75;
end
