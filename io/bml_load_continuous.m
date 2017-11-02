function raw = bml_load_continuous(cfg)

% BML_LOAD_CONTINUOUS loads continuous raw from one or more files
%
% Use as 
%   raw = bml_load_continuous(cfg)
%
% cfg is configuratin struct
%   cfg.folder
%   cfg.channel
%   cfg.chantype
%   cfg.Fs
%   cfg.roi - roi table (see BML_ROI_TABLE) Annotations should not overlap.
%   cfg.timetol - double: time tolerance in seconds per sample. Defaults to 1e-6
%   cfg.chantype - string
%
% returns a continuous FT_DATATYPE_RAW 

folder    = string(bml_getopt(cfg,'folder'));
channel   = string(bml_getopt(cfg,'channel'));
chantype  = string(bml_getopt(cfg,'chantype'));
filetype  = string(bml_getopt(cfg,'filetype'));
Fs        = bml_getopt(cfg,'Fs');
roi       = bml_getopt(cfg,'roi');
timetol   = bml_getopt(cfg,'timetol',1e-6);

if ~isempty(folder)
  %ToDo: combine cfg.folder with roi.folder in a smart way
  roi.folder = repmat({folder},height(roi),1);
end

roi = bml_roi_table(roi);

%assert for no time overlaps between rows
if ~isempty(bml_annot_overlap(roi))
  roi %printing table for user
  error('annotations in roi table overlap');
end

if isempty(chantype) && ismember('chantype',roi.Properties.VariableNames)
  chantype  = unique(roi.chantype);
end
if isempty(filetype) && ismember('filetype',roi.Properties.VariableNames)
  filetype  = unique(roi.filetype);
end
if isempty(Fs) && ismember('Fs',roi.Properties.VariableNames)
  Fs        = unique(roi.Fs);
end
if length(filetype) ~= 1; error('unique filetype required'); end
if length(chantype) ~= 1; error('unique chantype required'); end
if length(Fs) ~= 1; error('unique Fs required'); end

%loading first raw
cfg=[]; cfg.chantype=chantype;
[s,e]=bml_crop_idx(roi(1,:));
cfg.trl = [s, e, 0];
% cfg.trl = [roi.s1(1) roi.s2(1) 0];
cfg.dataset=fullfile(roi.folder{1},roi.name{1});
raw = ft_preprocessing(cfg);

if ~isempty(channel)
  if ~ismember(channel,raw.label)
    error(char(strcat(channel,' not present in raw ',cfg.dataset,' \nAvailable channels are: ',strjoin(raw.label))));
  end
  cfg=[]; cfg.channel=channel{:};
  raw = ft_selectdata(cfg,raw);
end

% time = raw.time{1}+roi.t1(1);
time = raw.time{1}+bml_idx2time(roi(1,:),s);
raw.time{1} = time;
if abs(time(end)-bml_idx2time(roi(1,:),e)) > timetol; error('timetol violated'); end

for i=2:height(roi)
  %loading next raw
  cfg=[]; cfg.chantype=chantype;
  [s,e]=bml_crop_idx(roi(i,:));
  cfg.trl = [s, e, 0];
  %cfg.trl = [roi.s1(i) roi.s2(i) 0];
  cfg.dataset=fullfile(roi.folder{i},roi.name{i});
  next_raw = ft_preprocessing(cfg);
  
  if ~isempty(channel)
    if isstring(channel); channel = {char(channel)}; end
    cfg=[]; cfg.channel=channel;
    next_raw = ft_selectdata(cfg,next_raw);
  end
    
  %next_time = next_raw.time{1}+roi.t1(i);
  next_time = next_raw.time{1}+bml_idx2time(roi(i,:),s);
  next_raw.time{1} = next_time;
  if abs(next_time(end)-bml_idx2time(roi(i,:),e)) > timetol; error('timetol violated'); end
 
  %verifying contiguity
  delta_t = time(end) - next_time(1) + 1/Fs;
  if abs(delta_t) < timetol
    cfg1=[]; cfg1.timetol = timetol; cfg1.timeref = 'common';
    raw = bml_hstack(cfg1, raw, next_raw);
    
    time = raw.time{1};
  else %dealing with non-contiguous files
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



