function sync = bml_sync_transfer_neuroomega_chantype(cfg)

% BML_SYNC_TRANSFER_NEUROOMEGA_CHANTYPE transfer sync info from one chantype to another
%
% Use as 
%   sync = bml_sync_transfer_neuroomega_chantype(cfg)
%
% This function calculates synchronization rows for neuroomega channels,
% based on another sync channel. Normally neuroomega files are sync with the
% analog 2750Hz channel. This function creates registries for other
% channels (for example 'macro' and 'micro'), based on the synchronized channel. 
%
% cfg.roi           - original sync table (normaly with chantype=analog)
% cfg.chantype      - char, new chantype. Options are 'micro', 'macro',
%                     'analog', 'emg'
% cfg.time_channel  - char, channel of new chantype used to extract time
%                     use 'CRAW_01___Central', etc. 
%                     if not provided uses the first channel of the
%                     correct chantype from the first entry of cfg.roi
% cfg.sync_time_channel  - char, channel of original chantype used in sync
%                     use 'CANALOG_IN_1', etc
%                     if not provided uses the first channel of the
%                     correct chantype from the first entry of cfg.roi
% cfg.filetype      - char, defaults to 'neuroomega.mat'
%
% returns an roi table with the new entries for neuroomega files.
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
% 'emg'        | 'CEMG_1___01'
% 'events'     | (will use micro time)
% ----------------------------------------
%
%

filetype          = bml_getopt(cfg,'filetype','neuroomega.mat');
time_channel      = bml_getopt_single(cfg,'time_channel');
sync_time_channel = bml_getopt_single(cfg,'sync_time_channel');
chantype          = bml_getopt(cfg,'chantype');
roi               = bml_getopt(cfg,'roi');

assert(~isempty(chantype),'chantype required');
assert(~isempty(roi),'roi required');
assert(all(ismember({'chantype'},roi.Properties.VariableNames)));

roi.chantype = strrep(roi.chantype,'events','micro');

hdr1 = ft_read_header(fullfile(roi.folder{1},roi.name{1}),'chantype','chaninfo');
if isempty(time_channel)
  sel_time_channel = strcmp(hdr1.orig.chaninfo.chantype,chantype);
  assert(sum(sel_time_channel)>0,'no channel of specified chantype');
  time_channel = hdr1.orig.chaninfo(sel_time_channel,:).channel{1};
end
if isempty(sync_time_channel)
  sync_time_channel = hdr1.orig.chaninfo(strcmp(hdr1.orig.chaninfo.chantype,roi.chantype{1}),:).channel{1};
end

time_begin_var      = strcat(time_channel,'_TimeBegin');
time_end_var        = strcat(time_channel,'_TimeEnd');
sync_time_begin_var = strcat(sync_time_channel,'_TimeBegin');
sync_time_end_var   = strcat(sync_time_channel,'_TimeEnd');

REQUIRED_VARS = {'s1','t1','s2','t2','folder','name','nSamples','Fs','chantype','filetype'};
assert(all(ismember(REQUIRED_VARS,roi.Properties.VariableNames)),...
  'Variables %s required',strjoin(REQUIRED_VARS))

filetype_roi = roi(strcmp(roi.filetype,filetype),:);

sync=table();
for i=1:height(filetype_roi)
  row=filetype_roi(i,:);
  
  %creating coordinates of neuroomega channel used for original sync
  orig_coord=[];
  orig_coord.s1=1; orig_coord.s2=row.nSamples;
  
  %reading header
  hdr = ft_read_header(fullfile(row.folder{1},row.name{1}),'chantype',chantype);
  
  %creating coordinates of neuroomega channel to sync
  coord=[];
  coord.s1=1; coord.s2=hdr.nSamples;
  
  %loading time info from neuroomega file
  if ismember(time_begin_var,fields(hdr.orig.orig))
    coord.t1   = hdr.orig.orig.(time_begin_var);
    coord.t2   = hdr.orig.orig.(time_end_var);
    %(coord.t2 - coord.t1)*hdr.Fs == hdr.nSamples
  else
    error('%s not present as mat variable in %s. \nSpecify cfg.time_channel as one of %s',...
      time_begin_var,fullfile(row.folder{1},row.name{1}), strjoin(hdr.label));
  end
  if ismember(sync_time_begin_var,fields(hdr.orig.orig))
  	orig_coord.t1 = hdr.orig.orig.(sync_time_begin_var);
    orig_coord.t2 = hdr.orig.orig.(sync_time_end_var);
    %(orig_coord.t2 - orig_coord.t1)*row.Fs == row.nSamples
  else
    error('%s not present as mat variable in %s. \nSpecify cfg.time_channel as one of %s',...
      time_begin_var,fullfile(row.folder{1},row.name{1}), strjoin(hdr.label));
  end  

  if row.s1==1
    %treating begging of the file differently
    row.t1 = row.t1 + coord.t1 - orig_coord.t1;
  else
    %mapping original samples to new samples
    tmp_t1 = bml_idx2time(orig_coord,row.s1);  
    row.s1 = bml_time2idx(coord,tmp_t1); %mapping original s1 to new s1    
    %correcting t1, t2 for rounding errors
    row.t1 = row.t1 + bml_idx2time(coord,row.s1) - tmp_t1;    
  end
  
  if row.s2==row.nSamples
    %treating end of the file differently
    row.s2 = coord.s2;
    row.t2 = row.t2 + coord.t2 - orig_coord.t2;
  else
  	%mapping original samples to new samples    
    tmp_t2 = bml_idx2time(orig_coord,row.s2);   
    row.s2=bml_time2idx(coord,tmp_t2); %mapping original s2 to new s2
    %correcting t1, t2 for rounding errors
    row.t2 = row.t2 + bml_idx2time(coord,row.s2) - tmp_t2;
  end

  row.nSamples=hdr.nSamples;
  row.chantype=chantype;
  row.Fs=hdr.Fs;
  row.starts = row.t1 - 0.5 ./ row.Fs;
  row.ends = row.t2 + 0.5 ./ row.Fs;
  sync = [sync; row];

end

sync = bml_annot_table(sync);


