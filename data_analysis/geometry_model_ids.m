function out = geometry_model_ids(varargin)
%GEOMETRY_MODEL_IDS Geometry-only model ids and cache helpers.
%
%   ids = geometry_model_ids()
%   label = geometry_model_ids('label')
%   tf = geometry_model_ids('is', model_id)

persistent ids;
if isempty(ids)
    ids = {'kurz2017', 'stitt2016', 'rE'};
end

if nargin == 0
    out = ids;
    return;
end

if nargin == 1 && strcmp(varargin{1}, 'label')
    out = 'GEOMETRY';
    return;
end

if nargin == 2 && strcmp(varargin{1}, 'is')
    out = ismember(char(varargin{2}), ids);
    return;
end

error('geometry_model_ids:InvalidUsage', ...
    'Use geometry_model_ids(), geometry_model_ids(''label''), or geometry_model_ids(''is'', id).');
end
