function label = derive_multi_hrtf_cache_label(sofa_dir)
%DERIVE_MULTI_HRTF_CACHE_LABEL Cache label for a multi-HRTF SOFA folder.
%   label = DERIVE_MULTI_HRTF_CACHE_LABEL(sofa_dir) returns a safe basename
%   prefixed with MULTI_, e.g. MULTI_participants for
%   aux_data/HRTFs/SONICOM/participants/.

[~, folder_name] = fileparts(strip(sofa_dir, filesep));
safe_name = regexprep(folder_name, '[^A-Za-z0-9_-]', '_');
if isempty(safe_name)
    safe_name = 'hrtf_set';
end
label = ['MULTI_' safe_name];
end
