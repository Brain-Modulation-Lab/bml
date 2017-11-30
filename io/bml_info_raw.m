function info = bml_info_raw(cfg)

% BML_INFO_RAW return a annot table with OS and header info of each raw file in a folder. 
%
% Use as
%   tab = bml_info_raw(cfg);
%
% 'raw' files are those that can be read by ft_read_header.
%
% The first argument cfg is a configuration structure, which can contain
% the following field:
% cfg.path - string: path to the folder containing the files. Defauts to '.'
% cfg.has_channel - cell of strings: channels required 
%
% Returns a matlab 'table' with the folloing variables:
%   starts - double: time in seconds 
%   ends - double: time in seconds 
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

chantype    = bml_getopt(cfg, 'chantype', {}); 
path        = bml_getopt(cfg, 'path');
has_channel = bml_getopt(cfg, 'has_channel'); 

info        = bml_info_file(cfg);

if isempty(info); return; end
info = info(info.bytes > 0,:);  
  
hdr_vars={'chantype','Fs','nSamples','nChans','nTrials','chanunit'};
hdr_table = cell2table(cell(height(info),length(hdr_vars)));
hdr_table.Properties.VariableNames = hdr_vars;

for i=1:height(info)
    hdr = ft_read_header(fullfile(info.folder{i},info.name{i}),'chantype',chantype);
    if ~isempty(has_channel)
      if ~all(ismember(has_channel,hdr.label))
        continue
      end
    end      
    hdr_table.chantype(i) = {strjoin(unique(hdr.chantype))};
    hdr_table.Fs(i) = {hdr.Fs};
    hdr_table.nSamples(i) = {hdr.nSamples};
    hdr_table.nChans(i) = {hdr.nChans};  
    hdr_table.nTrials(i) = {hdr.nTrials};    
    hdr_table.chanunit(i) = {strjoin(unique(hdr.chanunit))}; 
end

filtvec = ~cellfun(@isempty,hdr_table.nChans);
hdr_table = hdr_table(filtvec,:);

hdr_table.Fs = cell2mat(hdr_table.Fs);
hdr_table.nSamples = cell2mat(hdr_table.nSamples);
hdr_table.nChans = cell2mat(hdr_table.nChans);
hdr_table.nTrials = cell2mat(hdr_table.nTrials);

info = [info(filtvec,:) hdr_table];
info.duration = info.nSamples ./ info.Fs;
ends=bml_date2sec(info{:,'date'});
starts = ends-info.duration;

info=[table(starts,ends,'VariableNames',{'starts','ends'}) info];
% info=sortrows(info,'starts');
info=bml_annot_table(info,'raw_info');



