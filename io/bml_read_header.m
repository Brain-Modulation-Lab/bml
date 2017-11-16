function hdr = bml_read_header(cfg)

% BML_READ_HEADER
%
% cfg.name - string: filename
% cfg.folder - string: path to file
%
% returns fieldtrip header

name    = bml_getopt_single(cfg,'name');
folder  = bml_getopt_single(cfg,'folder');

assert(~isempty(name),"cfg.name required")
if isempty(folder); folder = "."; end

hdr = ft_read_header(fullfile(folder,name),'chantype','chaninfo');