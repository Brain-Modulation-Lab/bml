function hdr = bml_read_header(cfg)

% BML_READ_HEADER reads header of a file
%
% Use as
%   hdr = bml_read_header(cfg)
%
% cfg.name - string: filename
% cfg.folder - string: path to file
%
% returns fieldtrip header

if ~isstruct(cfg)
  cfg=struct('name',cfg);
end

name    = bml_getopt_single(cfg,'name');
folder  = bml_getopt_single(cfg,'folder');

assert(~isempty(name),"cfg.name required")
if isempty(folder); folder = "."; end

hdr = ft_read_header(fullfile(folder,name),'chantype','chaninfo');