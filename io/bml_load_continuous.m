function [raw, file_raw_map] = bml_load_continuous(cfg)

% BML_LOAD_CONTINUOUS loads continuous raw from one or more files
%
% Use as 
%   raw = bml_load_continuous(cfg)
%   raw = bml_load_continuous(cfg.roi)
%   [raw, file_raw_map] = bml_load_continuous(cfg)
%   [raw, file_raw_map] = bml_load_continuous(cfg.roi)
%
% cfg is configuratin struct
%   cfg.roi - ROI table with regions of interest to load
%   cfg.channel - cellstr with channels to be selected
%   cfg.electrode - ANNOT table with electrodes information. Should contain
%                   variables 'channel' and 'electrode'. Optional.
%   cfg.folder - overwrites info in cfg.roi
%   cfg.chantype - overwrites info in cfg.roi
%   cfg.filetype - overwrites info in cfg.roi
%   cfg.Fs - overwrites info in cfg.roi
%   cfg.timetol - double: time tolerance in seconds per sample. Defaults to 1e-6
%   cfg.chantype - string
%   cfg.dryrun - logical: should a dry-run test be performed? Defaults to false
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
% returns a continuous FT_DATATYPE_RAW and optionally a file-raw mapping
%
% -------------------------------------------------------------------------
%
% This function loads a fieldtrip data structure representing a raw continuous 
% in the form of a channels by times matrix (see FT_DATATYPE_RAW). The main
% argument is cfg.roi, ROI table with the synchronization file coordinates.
%

%% READING ARGUMENTS
file_raw_map_vars = {'starts','ends','s1','t1','s2','t2','folder','name','nSamples','Fs'};

if istable(cfg)
  cfg = struct('roi',cfg);
end

folder        = bml_getopt(cfg,'folder');
channel       = bml_getopt(cfg,'channel');
chantype      = bml_getopt(cfg,'chantype');
filetype      = bml_getopt(cfg,'filetype');
Fs            = bml_getopt(cfg,'Fs');
roi           = bml_annot_table(bml_getopt(cfg,'roi'),'roi');
timetol       = bml_getopt(cfg,'timetol',1e-5);
dryrun        = bml_getopt(cfg,'dryrun',false);
ft_feedback   = bml_getopt_single(cfg,'ft_feedback','no');
discontinuous = bml_getopt(cfg,'discontinuous','warn');
padval        = bml_getopt(cfg,'padval',0);
electrode     = bml_annot_table(bml_getopt(cfg,'electrode'),'electrode');

if isempty(roi)
  raw=[];
  return  
end
roi = bml_roi_table(roi);

if islogical(discontinuous)
  if istrue(discontinuous)
    discontinuous = {'allow'};
  else
    discontinuous = {'no'};
  end
end

% %assert for no time overlaps between rows
% cfg1=[]; cfg1.timetol = timetol;
% if ~isempty(bml_annot_overlap(cfg1,roi))
%   roi %printing table for user
%   error('annotations in roi table overlap');
% end

%consolidating chunks of same file when possible
roi = bml_sync_consolidate(roi);

%removing zero length rois
roi = roi(roi.duration > 0,:);

if ~isempty(folder)
  %ToDo: combine cfg.folder with roi.folder in a smart way
  roi.folder = repmat({folder},height(roi),1);
end

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

%dealing with skip factors
skipFactor=1;
chantype_split=strsplit(chantype{1},':');
if numel(chantype_split) == 2
  skipFactor=str2double(chantype_split{2});
elseif numel(chantype_split) > 2
  ft_error('Use '':'' to specify skipfactor, e.g. analog:10')
end

%selecting electrodes 
if ~isempty(electrode)
  assert(ismember('channel',electrode.Properties.VariableNames),"'channel' variable required in cfg.electrode");
  assert(ismember('electrode',electrode.Properties.VariableNames),"'electrode' variable required in cfg.electrode");
  %checking electrodes for time, filetype and chantype
  cfg1=[];
  cfg1.keep='x';
  cfg1.warn=false;
  electrode = bml_annot_intersect(cfg1,electrode,...
                  bml_annot_table(table(min(roi.starts),max(roi.ends))));
  assert(height(electrode)>0,"no electrode for roi time");
  if ismember('filetype',electrode.Properties.VariableNames)
    electrode = electrode(strcmp(electrode.filetype,filetype),:);
    assert(height(electrode)>0,"incorrect filetype for cfg.electrode");
  end
  if ismember('chantype',electrode.Properties.VariableNames)
    electrode = electrode(...  
      contains(electrode.chantype,{chantype{1}},'IgnoreCase',true)|...
      strcmp(electrode.chantype,'all')|...
      strcmp(electrode.chantype,'any')|...
      strcmp(electrode.chantype,'NA')|...
      strcmp(electrode.chantype,''),:);
    assert(height(electrode)>0,"incorrect chantype for cfg.electrode");
  else
    fprintf("electrode table has no chantype variable.\n")
  end
  
  assert(numel(electrode.channel)==numel(unique(electrode.channel)),...
      "repeated electrode entries for time/filetype/chantype");

  if isempty(channel)
  	channel = electrode.channel;
  end
end

%optimizing channel selection for trellis files
if ~isempty(channel) && contains(filetype,"trellis")
  chantype = {['^(',strjoin(channel,'|'),')$']};
  if skipFactor > 1
    chantype{1} = [chantype{1},':',num2str(skipFactor)];
  end
  channel=[];
end

%% LOAD FIRST FILE

%saving mapping between raw and files 
file_raw_map=roi(1,file_raw_map_vars);
[s,e]=bml_crop_idx_valid(roi(1,:));
file_raw_map.s1=s;
file_raw_map.s2=e;
file_raw_map.t1=bml_idx2time(roi(1,:),s);
file_raw_map.t2=bml_idx2time(roi(1,:),e);
file_raw_map.raw1=1;
file_raw_map.raw2=floor((e-s+1)/skipFactor);
file_raw_map.skipFactor = skipFactor;

%loading first raw
cfg=[]; 
cfg.chantype=chantype;
cfg.trl = [ceil(s/skipFactor), floor(e/skipFactor), 0];
cfg.dataset=fullfile(roi.folder{1},roi.name{1});
cfg.feedback=ft_feedback;
hdr = ft_read_header(cfg.dataset,'chantype',cfg.chantype);

%checking nomimal sampling frequencies
assert(hdr.Fs*skipFactor==roi.Fs(1),...
  'File %s chantype %s has Fs %f, not %f as defined in cfg.roi',...
  roi.name{1},cfg.chantype,hdr.Fs,roi.Fs(1));

if ~dryrun
  raw = ft_preprocessing(cfg);
else
  raw = hdr;
  assert(raw.nSamples>=floor(e/skipFactor),'index overflow s2=%i but nSample=%i',floor(e/skipFactor),raw.nSamples);
end

%selecting channels
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
time = bml_idx2time(roi(1,:),ceil(s/skipFactor):floor(e/skipFactor),skipFactor);
raw.time{1} = time;
if abs(time(end)-bml_idx2time(roi(1,:),floor(e/skipFactor),skipFactor)) > timetol
  error('timetol violated')
end

%% LOAD OTHER FILES (if present)
for i=2:height(roi)
  
  %saving mapping between raw and files 
  row=roi(i,file_raw_map_vars);
  [s,e]=bml_crop_idx_valid(roi(i,:));
  row.s1=s;
  row.s2=e;
  row.t1=bml_idx2time(roi(i,:),s);
  row.t2=bml_idx2time(roi(i,:),e);
  row.raw1=max(file_raw_map.raw2)+1;
  row.raw2=floor((e-s)/skipFactor)+row.raw1;
  row.skipFactor = skipFactor;
  
  %loading next raw
  cfg=[]; 
  cfg.chantype=chantype;
  cfg.trl = [ceil(s/skipFactor), floor(e/skipFactor), 0];
  cfg.dataset=fullfile(roi.folder{i},roi.name{i});
  cfg.feedback=ft_feedback;
  if ~dryrun
    next_raw = ft_preprocessing(cfg);
  else
    next_raw = ft_read_header(cfg.dataset,'chantype',cfg.chantype);
    assert(next_raw.nSamples>=floor(e/skipFactor),'index overflow s2=%i but nSample=%i',floor(e/skipFactor),next_raw.nSamples);
  end
  
  if ~isempty(channel)
    if isstring(channel); channel = {char(channel)}; end
    if ~dryrun
      cfg=[]; cfg.channel=channel; cfg.feedback=ft_feedback;
      next_raw = ft_selectdata(cfg,next_raw);
    end
  end
    
  %next_time = next_raw.time{1}+bml_idx2time(roi(i,:),s);
  next_time = bml_idx2time(roi(i,:),ceil(s/skipFactor):floor(e/skipFactor),skipFactor);
  next_raw.time{1} = next_time;
  assert(abs(next_time(end)-bml_idx2time(roi(i,:),floor(e/skipFactor),skipFactor)) < timetol, 'timetol violated');
 
  %verifying contiguity
  delta_t = next_time(1) - time(end) - skipFactor/Fs;
  if abs(delta_t) > timetol %non contiguous files
    if ~ismember(discontinuous,{'allow','warn'})
      roi
      error("To concateneting discontinuous rois use cfg.discontinuous='allow'");
    end  
    
    delta_s = delta_t*Fs/skipFactor;
    delta_s_int = round(delta_s);
    assert(delta_s>0,"overlaping rois can't be concatenated"); 

    if abs(delta_s_int - delta_s) < timetol*Fs/skipFactor
      if ismember(discontinuous,{'warn'})
        warning("concatenating discontinous files %i samples added",delta_s_int);
      end
      if ~dryrun             
        %zero padding the end of the previous raw
        starts = raw.time{1}(1) - 0.5*skipFactor/Fs;
        ends = next_time(1) + 0.5*skipFactor/Fs;
        [raw, ~, post] = bml_pad(raw,starts,ends,padval);
        
        %correcting raw mapping due to zero padding
        %the starts of next file in raw coordinates is delayed by post
        row.raw1=max(file_raw_map.raw2)+1+post;
        row.raw2=floor((e-s)/skipFactor)+row.raw1;
      else
        time = [time,time(end)+(1:delta_s_int)*skipFactor/Fs];
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
  
  file_raw_map = [file_raw_map;row];
end

if dryrun
  raw = [];
elseif ~isempty(electrode)
  %changing labels from channels to electrodes
	raw.label = bml_map(raw.label,electrode.channel,electrode.electrode);
end

file_raw_map = bml_roi_table(file_raw_map);




