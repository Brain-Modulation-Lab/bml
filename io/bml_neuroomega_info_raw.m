function info = bml_neuroomega_info_raw(cfg)

% BML_NEUROOMEGA_INFO_RAW returns a table with the information of each raw neuroomega .mat file in a
% folder.
%
% Use as
%   tab = bml_neuroomega_info_raw(cfg);
%
% Raw files can be read by ft_read_header.
%
% The first argument cfg is a configuration structure, which can contain
% the following field:
% cfg.path - string: path to the folder containing the .mat files. Defauts to '.'
% cfg.pattern - string: file name pattern (defaults to '*.mat')
% cfg.regexp - string: regular expression to filter files (defaults to '[RL]T[1-5]D[-]{0,1}\d+\.\d+([+-]M){0,1}F\d+\.mat')
% cfg.time_channel - string: channel to use for TimeBegin and TimeEnd (defaults to 'CANALOG_IN_1')
% cfg.chantype - string: channel type. Defaults to 'chaninfo'
%
% Returns a matlab 'table' with the folloing variables:
%   name - cell array of char: filename
%   folder - cell array of char: path
%   date - cell array of char: data of file modification 
%   bytes - double: Size of the file in bytes
%   isdir - logical: 1 if name is a folder; 0 if name is a file
%   datenum - double: Modification date as serial date number.
%   chantype
%   Fs
%   nSamples
%   nChans
%   nTrials
%   chantype
%   chanunit
%   duration
%   start
%   end

% 2017.10.20 AB
chantype       = ft_getopt(cfg, 'chantype', 'chaninfo');   
time_channel = ft_getopt(cfg,'time_channel','CANALOG_IN_1');
time_begin = strcat(time_channel,'_TimeBegin');
time_end = strcat(time_channel,'_TimeEnd');

info = bml_neuroomega_info_file(cfg);

hdr_vars={'chantype','Fs','nSamples','nChans','nTrials','chanunit','time_begin','time_end'};
hdr_table = cell2table(cell(size(info,1),length(hdr_vars)));
hdr_table.Properties.VariableNames = hdr_vars;

for i=1:height(info)
  hdr = ft_read_header(fullfile(cfg.path,info.name{i}),'chantype',chantype);
  hdr_table.chantype(i) = {strjoin(unique(hdr.chantype))};
  hdr_table.Fs(i) = {hdr.Fs};
  hdr_table.nSamples(i) = {hdr.nSamples};
  hdr_table.nChans(i) = {hdr.nChans};  
  hdr_table.nTrials(i) = {hdr.nTrials};    
  hdr_table.chanunit(i) = {strjoin(unique(hdr.chanunit))}; 
  hdr_table.time_begin(i) = {hdr.orig.(time_begin)};
  hdr_table.time_end(i) = {hdr.orig.(time_end)};
end
hdr_table.Fs = cell2mat(hdr_table.Fs);
hdr_table.nSamples = cell2mat(hdr_table.nSamples);
hdr_table.nChans = cell2mat(hdr_table.nChans);
hdr_table.nTrials = cell2mat(hdr_table.nTrials);
hdr_table.time_begin = cell2mat(hdr_table.time_begin);
hdr_table.time_end = cell2mat(hdr_table.time_end);

info = [info hdr_table];

%info.duration = info.nSamples ./ info.Fs; %date of mat is not informative
%ends = bml_date2sec(info.date);
%starts = ends-info.duration;
%info=[table(starts,ends,'VariableNames',{'starts','ends'}) info];
%info=sortrows(info,'starts');
info=sortrows(info,'time_begin');



