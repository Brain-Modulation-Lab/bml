function event = bml_read_event(cfg)

% BML_READ_EVENT
%
% cfg.name - string: filename
% cfg.folder - string: path to file
%
% returns fieldtrip event

name    = bml_getopt(cfg,'name');
folder  = bml_getopt(cfg,'folder');

assert(numel(name)==1,'single name required');
if iscell(name); name = name{1}; end

if isempty(folder); folder = "."; end
assert(numel(folder)==1,'single folder required');
if iscell(folder); folder = folder{1}; end

event = ft_read_event(fullfile(folder,name));