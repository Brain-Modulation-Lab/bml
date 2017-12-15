function info = bml_neuroomega_info_raw(cfg)

% BML_NEUROOMEGA_INFO_RAW returns table with OS and header info of raw neuroomega.mat (.mpx) files.
%
% Use as
%   tab = bml_neuroomega_info_raw(cfg);
%
% 'raw' files can be read by ft_read_header.
%
% The first argument cfg is a configuration structure, which can contain
% the following field:
% cfg.chantype - string: channel type. Required (see table below)
% cfg.path - string: path to the folder containing the .mat files. Defauts to '.'
% cfg.pattern - string: file name pattern (defaults to '*.mat')
% cfg.regexp - string: regular expression to filter files (defaults to '[RL]T[1-5]D[-]{0,1}\d+\.\d+([+-]M){0,1}F\d+\.mat')
% cfg.time_channel - string: channel to use for TimeBegin and TimeEnd 
%               defaults to first channel of indicated chantype in first
%               file detected.
% cfg.rm_vars - cell of char with variables names to be removed if present
%               defaults to {'time_end','time_begin','filenum'}
% cfg.mpx_path - string: path to the folder containing the .mpx_ files. Defauts to cfg.path
% cfg.mpx_pattern - string: file name pattern (defaults to '*.mpx')
% cfg.mpx_regexp - string: regular expression to filter files (defaults to '[RL]T[1-5]D[-]{0,1}\d+\.\d+([+-]M){0,1}F\d+\.mpx')
%
%
% Returns a matlab 'table' with the folloing variables:
%   start - double: time in seconds (calculated if mpx files are found in cfg.mpx_path)  
%   end - double: time in seconds (calculated if mpx files are found in cfg.mpx_path)
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
%
%
%
% ----------------------------------------
% chantype     |   example channel
% ----------------------------------------
% 'macro'      | 'CMacro_RAW_01___Central'
% 'micro'      | 'CRAW_01___Central'
% 'micro_hp'   | 'CSPK_01___Central'
% 'analog'     | 'CANALOG_IN_1'
% 'add_analog' | 'CADD_ANALOG_IN_1'
% 'micro_lfp'  | 'CLFP_01___Central'
% 'macro_lfp'  | 'CMacro_LFP_01___Central
% ----------------------------------------
%

chantype       = bml_getopt(cfg, 'chantype');   
time_channel   = bml_getopt_single(cfg,'time_channel');

info = bml_neuroomega_info_file(cfg);

cfg_mpx=[];
cfg_mpx.path    = bml_getopt(cfg,'mpx_path',ft_getopt(cfg,'path','.'));
cfg_mpx.pattern = bml_getopt(cfg,'mpx_pattern','*.mpx');
cfg_mpx.regexp  = bml_getopt(cfg,'mpx_regexp','[RL]T[1-5]D[-]{0,1}\d+\.\d+([+-]M){0,1}F\d+\.mpx');
rm_vars         = bml_getopt(cfg,'rm_vars',{'time_end','time_begin','filenum'});

info_mpx=bml_info_file(cfg_mpx);

hdr_vars={'chantype','Fs','nSamples','nChans','nTrials','chanunit','time_begin','time_end'};
hdr_table = cell2table(cell(size(info,1),length(hdr_vars)));
hdr_table.Properties.VariableNames = hdr_vars;

assert(~isempty(chantype),'cfg.chantype required');
if isempty(time_channel)
  hdr1 = ft_read_header(fullfile(info.folder{1},info.name{1}),'chantype','chaninfo');
  time_channel = hdr1.chaninfo(strcmp(hdr1.chaninfo.chantype,chantype),:).channel{1};
end
time_begin     = strcat(time_channel,'_TimeBegin');
time_end       = strcat(time_channel,'_TimeEnd');

for i=1:height(info)
  hdr = ft_read_header(fullfile(info.folder{i},info.name{i}),'chantype',chantype);
  hdr_table.chantype(i) = {strjoin(unique(hdr.chantype))};
  hdr_table.Fs(i) = {hdr.Fs};
  hdr_table.nSamples(i) = {hdr.nSamples};
  hdr_table.nChans(i) = {hdr.nChans};  
  hdr_table.nTrials(i) = {hdr.nTrials};    
  hdr_table.chanunit(i) = {strjoin(unique(hdr.chanunit))}; 

  if ismember(time_begin,fields(hdr.orig))
    hdr_table.time_begin(i) = {hdr.orig.(time_begin)};
    hdr_table.time_end(i) = {hdr.orig.(time_end)};
  else
    error('%s not present as mat variable in %s. \nSpecify cfg.time_channel as one of %s',...
      time_begin,fullfile(cfg.path,info.name{i}), strjoin(hdr.label));
  end
end
hdr_table.Fs = cell2mat(hdr_table.Fs);
hdr_table.nSamples = cell2mat(hdr_table.nSamples);
hdr_table.nChans = cell2mat(hdr_table.nChans);
hdr_table.nTrials = cell2mat(hdr_table.nTrials);
hdr_table.time_begin = cell2mat(hdr_table.time_begin);
hdr_table.time_end = cell2mat(hdr_table.time_end);

info = [info hdr_table];

if ~isempty(info_mpx) %loading date from .mpx OS info if available
  info_mpx.basename = erase(info_mpx.name,'.mpx');
  info_mpx=info_mpx(:,{'basename','date','datenum'});
  
  info.date=[];
  info.datenum=[];
  info.basename = erase(info.name,'.mat');
  
  info=join(info,info_mpx,'Keys','basename');

  %adjusting time_end to bml_date2sec origin.
  ends = info.time_end+median(bml_date2sec(info.date)-info.time_end);
  %NOTE: time_start and time_end are time coordinates of the first and 
  %last data point. Duration is the length of the 'represented' time
  %therefore the correct way of calculating duration is as follows:
  info.duration = info.time_end - info.time_begin + 1./info.Fs; 
  starts = ends - info.duration;
  info = [table(starts,ends,'VariableNames',{'starts','ends'}) info];
  info.basename = [];
  %info=sortrows(info,'starts');
  info = bml_annot_table(info);
else
  warning('Specify cfg.mpx_path for starts/ends calculation')
  info=sortrows(info,'time_begin');
end

for i=1:numel(rm_vars)
  if ismember(rm_vars(i),info.Properties.VariableNames)
    info.(rm_vars{i}) = [];
  end
end  
  




