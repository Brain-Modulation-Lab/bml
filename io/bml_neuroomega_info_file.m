function info = bml_neuroomega_info_file(cfg)

% BML_NEUROOMEGA_INFO_FILE returns table with OS info of each neuroomega.mat file in a folder
%
% Use as
%   tab = bml_neuroomega_info_file(cfg);
%
% Same as BML_INFO_FILE but extracts depth and filenumber from filename.
%
% The first argument cfg is a configuration structure, which can contain
% the following field:
% cfg.path - string: path to the folder containing the .mat files. Defauts to '.'
% cfg.pattern - string: file name pattern (defaults to '*.mat')
% cfg.moving_files - logical: should Moving Files (MF) be loaded. Defaults to true.  
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

cfg.pattern  = bml_getopt(cfg,'pattern','*.mat');
moving_files = bml_getopt(cfg,'moving_files',true); 
if istrue(moving_files)
  cfg.regexp   = bml_getopt(cfg,'regexp','[RL]T[1-5]D[-]{0,1}\d+\.\d+([+-]M){0,1}F\d+\.mat');
else
  cfg.regexp   = bml_getopt(cfg,'regexp','[RL]T[1-5]D[-]{0,1}\d+\.\d+F\d+\.mat');
end

info = bml_info_file(cfg);

info.depth = cellfun(@(x) str2double(regexp(x,'-?\d+\.\d+','match')), info.name);
info.filenum = cellfun(@(x) str2double(regexp(x,'F(\d+)\.mat','tokens','once')), info.name);


