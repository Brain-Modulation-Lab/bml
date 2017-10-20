function info = bml_info_raw(cfg)

% BML_INFO_RAW returns a table with the information of each raw file in a
% folder. 
%
% Use as
%   tab = bml_info_raw(cfg);
%
% Raw files can be read by ft_read_header.
%
% The first argument cfg is a configuration structure, which can contain
% the following field:
% cfg.path - string: path to the folder containing the files. Defauts to '.'
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

% 2017.10.19 AB

chantype       = ft_getopt(cfg, 'chantype', {});   
info = bml_info_file(cfg);

hdr_vars={'chantype','Fs','nSamples','nChans','nTrials','chanunit'};
hdr_table = cell2table(cell(size(info,1),length(hdr_vars)));
hdr_table.Properties.VariableNames = hdr_vars;

for i=1:size(info,1)
  hdr = ft_read_header(fullfile(cfg.path,info.name{i}),'chantype',chantype);
  hdr_table.chantype(i) = {strjoin(unique(hdr.chantype))};
  hdr_table.Fs(i) = {hdr.Fs};
  hdr_table.nSamples(i) = {hdr.nSamples};
  hdr_table.nChans(i) = {hdr.nChans};  
  hdr_table.nTrials(i) = {hdr.nTrials};    
  hdr_table.chanunit(i) = {strjoin(unique(hdr.chanunit))}; 
end
hdr_table.Fs = cell2mat(hdr_table.Fs);
hdr_table.nSamples = cell2mat(hdr_table.nSamples);
hdr_table.nChans = cell2mat(hdr_table.nChans);
hdr_table.nTrials = cell2mat(hdr_table.nTrials);

info = [info hdr_table];
info.duration = info.nSamples ./ info.Fs;
ends=bml_date2sec(info.date);
starts = ends-info.duration;
info=[table(starts,ends,'VariableNames',{'starts','ends'}) info];
info=sortrows(info,'starts');



