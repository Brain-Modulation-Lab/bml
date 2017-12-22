function event = bml_read_event(cfg)

% BML_READ_EVENT reads fieldtrip's event structures from files
%
% cfg.name - string: filename
% cfg.folder - string: path to file
% cfg.detectflank - 'up', 'down' or 'both' (default)
%
% returns fieldtrip event structure

name         = bml_getopt(cfg,'name');
folder       = bml_getopt(cfg,'folder');
detectflank  = bml_getopt_single(cfg,'detectflank','both');

assert(numel(name)==1,'single name required');
if iscell(name); name = name{1}; end

if isempty(folder); folder = "."; end
assert(numel(folder)==1,'single folder required');
if iscell(folder); folder = folder{1}; end

try
  event = ft_read_event(fullfile(folder,name),'detectflank',detectflank);
catch
  warning('cound not read events from %s',fullfile(folder,name));
  event = [];
end

