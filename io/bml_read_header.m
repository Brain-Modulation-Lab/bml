function hdr = bml_read_header(cfg)

% BML_READ_HEADER reads header of a file
%
% Use as
%   hdr = bml_read_header(cfg)
%   hdr = bml_read_header(cfg.roi)
%
% cfg.roi - table of height 1 with folder and name variables
% cfg.name - string: filename
% cfg.folder - string: path to file
% cfg.chantype - string: channel type. Defualts to 'chaninfo'
%
% returns fieldtrip header

if istable(cfg)
  assert(height(cfg)==1,"Only one row tables allowed as cfg");
elseif isstruct(cfg)
  chantype = bml_getopt_single(cfg,'chantype','chaninfo');
  if ismember('roi',fieldnames(cfg)) && istable(cfg.roi) && height(cfg.roi)==1
    cfg = cfg.roi;
  end
else
  cfg=struct('name',cfg);
end

name    = bml_getopt_single(cfg,'name');
folder  = bml_getopt_single(cfg,'folder');

assert(~isempty(name),"cfg.name required")
if isempty(folder); folder = '.'; end

hdr = ft_read_header(fullfile(folder,name),'chantype',chantype);

