function [raw, file_raw_map] = bml_load_continuous(cfg)

% BML_LOAD_CONTINUOUS loads continuous raw from one or more files
%
% Use as 
%   raw = bml_load_continuous(cfg)
%   raw = bml_load_continuous(roi_table)
%   [raw, file_raw_map] = bml_load_continuous(cfg)
%   [raw, file_raw_map] = bml_load_continuous(roi_table)
%
% cfg is configuratin struct
%   cfg.folder
%   cfg.channel
%   cfg.chantype
%   cfg.filetype
%   cfg.Fs
%   cfg.roi - roi table (see BML_ROI_TABLE) Annotations should not overlap.
%   cfg.timetol - double: time tolerance in seconds per sample. Defaults to 1e-6
%   cfg.chantype - string
%   cfg.dryrun - logical: should a dry-run test be performed?
%   cfg.ft_feedback - string: default to 'no'. Defines verbosity of fieldtrip
%           functions 
%   cfg.discontinuous - string or logical: 
%           * true or 'allow' to allow discontinous files to be loaded filling 
%           the gap with zero-padding, if possible within timetol.
%           * false or 'no' to issue an error if discontinous files are found
%           * 'warn' to allow with a warning
%   cfg.padval - value with which to pad if discontinuous files are loaded.
%           Defualts to zero
%
% roi_table is what would go in the cfg.roi field 
%
% returns a continuous FT_DATATYPE_RAW and optionally a raw table

file_raw_map_vars = {'starts','ends','s1','t1','s2','t2','folder','name','nSamples','Fs'};

if istable(cfg)
  cfg = struct('roi',cfg);
end

folder        = bml_getopt(cfg,'folder');
channel       = bml_getopt(cfg,'channel');
chantype      = bml_getopt(cfg,'chantype');
filetype      = bml_getopt(cfg,'filetype');
Fs            = bml_getopt(cfg,'Fs');
roi           = bml_roi_table(bml_getopt(cfg,'roi'));
timetol       = bml_getopt(cfg,'timetol',1e-6);
dryrun        = bml_getopt(cfg,'dryrun',false);
ft_feedback   = bml_getopt_single(cfg,'ft_feedback','no');
discontinuous = bml_getopt(cfg,'discontinuous','warn');
padval        = bml_getopt(cfg,'padval',0);

if islogical(discontinuous)
  if istrue(discontinuous)
    discontinuous = {'allow'};
  else
    discontinuous = {'no'};
  end
end

if ~isempty(folder)
  %ToDo: combine cfg.folder with roi.folder in a smart way
  roi.folder = repmat({folder},height(roi),1);
end

roi = bml_roi_table(roi);
if height(roi)==0
  raw=[];
  return  
end

%assert for no time overlaps between rows
if ~isempty(bml_annot_overlap(roi))
  roi %printing table for user
  error('annotations in roi table overlap');
end

%consolidating chunks of same file when possible
roi = bml_sync_consolidate(roi);

%using roi parameters if none specified in call
if isempty(chantype) && ismember('chantype',roi.Properties.VariableNames)
  chantype  = cellstr(unique(roi.chantype));
end
if isempty(filetype) && ismember('filetype',roi.Properties.VariableNames)
  filetype  = cellstr(unique(roi.filetype));
end
if isempty(Fs) && ismember('Fs',roi.Properties.VariableNames)
  Fs        = unique(roi.Fs);
end
assert(length(filetype)==1,'unique filetype required: %s',strjoin(filetype));
assert(length(chantype)==1,'unique chantype required: %s',strjoin(chantype));
assert(length(Fs)==1,'unique Fs required: %s',strjoin(string(num2str(Fs))));

%saving mapping between raw and files
file_raw_map=roi(1,file_raw_map_vars);
[s,e]=bml_crop_idx_valid(roi(1,:));
file_raw_map.s1=s;
file_raw_map.s2=e;
file_raw_map.t1=bml_idx2time(roi(1,:),s);
file_raw_map.t2=bml_idx2time(roi(1,:),e);
file_raw_map.raw1=1;
file_raw_map.raw2=e-s+1;

%dealing with skip factors
sf=1;
chantype_split=strsplit(chantype{1},':');
if numel(chantype_split) == 2
  sf=str2double(chantype_split{2});
elseif numel(chantype_split) > 2
  ft_error('Use : to specify skipfactor, e.g. analog:10')
end

%loading first raw
cfg=[]; cfg.chantype=chantype;
cfg.trl = [ceil(s/sf), floor(e/sf), 0];
cfg.dataset=fullfile(roi.folder{1},roi.name{1});
cfg.feedback=ft_feedback;
if ~dryrun
  raw = ft_preprocessing(cfg);
else
  raw = ft_read_header(cfg.dataset,'chantype',cfg.chantype);
  assert(raw.nSamples>=e,'index overflow s2=%i but nSample=%i',e,raw.nSamples);
end

if ~isempty(channel)
  channel_selected=ft_channelselection(channel,raw.label);
  if numel(channel_selected)==0
    error(char(strcat(channel,' not present in raw ',cfg.dataset,' \nAvailable channels are: ',strjoin(raw.label))));
  elseif ~dryrun
    cfg=[]; cfg.channel=channel; cfg.feedback=ft_feedback;
    raw = ft_selectdata(cfg,raw);
  end
end

% time = raw.time{1}+bml_idx2time(roi(1,:),s);
time = bml_idx2time(roi(1,:),s:e);
raw.time{1} = time;
if abs(time(end)-bml_idx2time(roi(1,:),e)) > timetol
  error('timetol violated')
end

for i=2:height(roi)
  
  %saving mapping between raw and files
  row=roi(i,file_raw_map_vars);
  [s,e]=bml_crop_idx_valid(roi(i,:));
  row.s1=s;
  row.s2=e;
  row.t1=bml_idx2time(roi(i,:),s);
  row.t2=bml_idx2time(roi(i,:),e);
  row.raw1=max(file_raw_map.raw2)+1;
  row.raw2=e-s+row.raw1;
  file_raw_map = [file_raw_map;row];
  
  %loading next raw
  cfg=[]; cfg.chantype=chantype;
  cfg.trl = [s, e, 0];
  cfg.dataset=fullfile(roi.folder{i},roi.name{i});
  cfg.feedback=ft_feedback;
  if ~dryrun
    next_raw = ft_preprocessing(cfg);
  else
    next_raw = ft_read_header(cfg.dataset,'chantype',cfg.chantype);
    assert(next_raw.nSamples>=e,'index overflow s2=%i but nSample=%i',e,next_raw.nSamples);
  end
  
  if ~isempty(channel)
    if isstring(channel); channel = {char(channel)}; end
    if ~dryrun
      cfg=[]; cfg.channel=channel; cfg.feedback=ft_feedback;
      next_raw = ft_selectdata(cfg,next_raw);
    end
  end
    
  %next_time = next_raw.time{1}+bml_idx2time(roi(i,:),s);
  next_time = bml_idx2time(roi(i,:),s:e);
  next_raw.time{1} = next_time;
  assert(abs(next_time(end)-bml_idx2time(roi(i,:),e)) < timetol, 'timetol violated');
 
  %verifying contiguity
  delta_t = next_time(1) - time(end) - 1/Fs;
  if abs(delta_t) > timetol %non contiguous files
    if ~ismember(discontinuous,{'allow','warn'})
      roi
      error("To concateneting discontinuous rois use cfg.discontinuous='allow'");
    end  
    
    delta_s = delta_t*Fs;
    delta_s_int = round(delta_s);
    assert(delta_s>0,"overlaping rois can't be concatenated"); 

    if abs(delta_s_int - delta_s) < timetol
      if ismember(discontinuous,{'warn'})
        warning("concatenating discontinous files %i samples added",delta_s_int);
      end
      if ~dryrun
        starts = raw.time{1}(1) - 0.5/Fs;
        ends = next_time(1) - 0.5/Fs;
        raw = bml_pad(raw,starts,ends,0);
      else
        time = [time,time(end)+(1:delta_s_int)/Fs];
      end
    else
    	roi
      error('can''t concatenate discontinuous files within timetol');
    end 
  end
    
  if ~dryrun
    cfg1=[]; cfg1.timetol = timetol; cfg1.timeref = 'common';
    raw = bml_hstack(cfg1, raw, next_raw);
    time = raw.time{1};
  else
    time = [time next_time];
  end
end
  
if dryrun
  raw = [];
end

file_raw_map = bml_roi_table(file_raw_map);

