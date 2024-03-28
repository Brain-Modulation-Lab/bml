function info = bml_info_file(cfg)

% BML_INFO_FILE returns table with OS info of each file in a folder
%
% Use as
%   tab = bml_info_file(cfg);
%
% The first argument cfg is a configuration structure, which can contain
% the following field:
% cfg.path - string: path to the folder containing the files. Defauts to '.'
% cfg.pattern - string: file name pattern (eg '*.mat')
% cfg.regexp - string: regular expression to filter files
% cfg.filetype - string: variable added to info table
%
% Returns a matlab 'table' with the following variables:
%   name - cell array of char: filename
%   folder - cell array of char: path
%   date - cell array of char: data of file modification 
%   bytes - double: Size of the file in bytes
%   isdir - logical: 1 if name is a folder; 0 if name is a file
%   datenum - double: Modification date as serial date number.

path        = bml_getopt_single(cfg,'path','.');
filepattern = bml_getopt_single(cfg,'pattern','*');
fileregexp  = bml_getopt_single(cfg,'regexp',[]);

filetype    = regexp(filepattern,'.*\.(.*)$','tokens','once');
if isempty(filetype); filetype = 'unknown'; end
filetype    = bml_getopt(cfg,'filetype',filetype);

files=dir(fullfile(path, filepattern));
if ~isempty(fileregexp)
  rx=regexp({files.name},fileregexp,'once');
  files=files(~cellfun(@isempty,rx));
end

if isempty(files)
  info=table();
else
  if length(files)==1
    files.name = {files.name};
    files.folder = {files.folder};
    files.date = {files.date};
  end
  info=struct2table(files);
  info.filetype = repmat(filetype,height(info),1);
end

