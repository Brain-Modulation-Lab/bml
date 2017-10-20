function info = bml_neuroomega_info_file(cfg)

% BML_NEUROOMEGA_INFO_FILE returns a table with the information of each .mat
% file in a folder
%
% Use as
%   tab = bml_neuroomega_info_file(cfg);
%
% The first argument cfg is a configuration structure, which can contain
% the following field:
% cfg.path - string: path to the folder containing the .mat files. Defauts to '.'
% cfg.pattern - string: file name pattern (defaults to '*.mat')
% cfg.regexp - string: regular expression to filter files (defaults to '[RL]T[1-5]D[-]{0,1}\d+\.\d+([+-]M){0,1}F\d+\.mat')
%
% Returns a matlab 'table' with the folloing variables:
%   name - cell array of char: filename
%   folder - cell array of char: path
%   date - cell array of char: data of file creation 
%   bytes - double: Size of the file in bytes
%   isdir - logical: 1 if name is a folder; 0 if name is a file
%   datenum - double: Modification date as serial date number.
%   depth - double: depth of the electrodes as extracted from the file name
%   filenum - double: index of the file at the specified depth

% 2017.10.20 AB

cfg.pattern = ft_getopt(cfg,'pattern','*.mat');
cfg.regexp  = ft_getopt(cfg,'regexp','[RL]T[1-5]D[-]{0,1}\d+\.\d+([+-]M){0,1}F\d+\.mat');

info = bml_info_file(cfg);

info.depth = cellfun(@(x) str2double(regexp(x,'-?\d+\.\d+','match')), info.name);
info.filenum = cellfun(@(x) str2double(regexp(x,'F(\d+)\.mat','tokens','once')), info.name);

% path = ft_getopt(cfg,'path','.');
% filepattern = ft_getopt(cfg,'pattern','*.mat');
% fileregexp  = ft_getopt(cfg,'regexp','[RL]T[1-5]D[-]{0,1}\d+\.\d+([+-]M){0,1}F\d+\.mat');
% 
% files=dir(fullfile(path, filepattern));
% if ~isempty(fileregexp)
%   rx=regexp({files.name},fileregexp,'once');
%   files=files(~cellfun(@isempty,rx));
% end
% 
% for i=1:numel(files)
%   files(i).depth=str2double(regexp(files(i).name,'-?\d+\.\d+','match'));
%   files(i).filenum=str2double(regexp(files(i).name,'F(\d+)\.mat','tokens','once'));
% end
% 
% if isempty(files)
%   info=table();
% else
%   info=struct2table(files);
% end

