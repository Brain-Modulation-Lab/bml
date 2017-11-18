function raw = bml_load_continuous(cfg)

% BML_LOAD_CONTINUOUS loads continuous raw from one or more files
%
% Use as 
%   raw = bml_load_continuous(cfg)
%   raw = bml_load_continuous(roi_table)
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
%
% roi_table is what would go in the cfg.roi field 
%
% returns a continuous FT_DATATYPE_RAW 

if istable(cfg)
  cfg = struct('roi',cfg);
end

folder      = bml_getopt(cfg,'folder');
channel     = bml_getopt(cfg,'channel');
chantype    = bml_getopt(cfg,'chantype');
filetype    = bml_getopt(cfg,'filetype');
Fs          = bml_getopt(cfg,'Fs');
roi         = bml_getopt(cfg,'roi');
timetol     = bml_getopt(cfg,'timetol',1e-6);
dryrun      = bml_getopt(cfg,'dryrun',false);
ft_feedback = bml_getopt_single(cfg,'ft_feedback','no');

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

%consolidating chunks if of same file
if height(roi)>1 && length(unique(roi.name))==1 && length(unique(roi.folder))==1
  %ToDo: improve consolidation algorithm
  consrow = roi(1,:);
  consrow.starts = min(roi.starts);
  consrow.ends = max(roi.ends);
  consrow.s1 = min(roi.s1);
  consrow.s2 = min(roi.s2);
  consrow.t1 = min(roi.t1);
  consrow.t2 = min(roi.t2);
  consrow.warpfactor = sum(roi.warpfactor .* roi.duration)/sum(roi.duration);
  roi = consrow;
end

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

%loading first raw
cfg=[]; cfg.chantype=chantype;
[s,e]=bml_crop_idx_valid(roi(1,:));
cfg.trl = [s, e, 0];
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
if abs(time(end)-bml_idx2time(roi(1,:),e)) > timetol; error('timetol violated'); end

for i=2:height(roi)
  %loading next raw
  cfg=[]; cfg.chantype=chantype;
  [s,e]=bml_crop_idx_valid(roi(i,:));
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
  delta_t = time(end) - next_time(1) + 1/Fs;
  if abs(delta_t) < timetol
    if ~dryrun
      cfg1=[]; cfg1.timetol = timetol; cfg1.timeref = 'common';
      raw = bml_hstack(cfg1, raw, next_raw);
      time = raw.time{1};
    else
      time = [time next_time];
    end
  else %dealing with non-contiguous files
    roi
    error('concatenating non-contiguous files is not supported yet');
    keyboard
    %delta_s=round(delta_t/Fs);
    %if abs(delta_t/Fs - delta_s) < timetol * delta_s %checking relative error
    % snap next_times in-frame with times
    %else
    % error('non-contiguos files can''t be merged within timetol')
    %end
  end
end

if dryrun
  raw = [];
end


