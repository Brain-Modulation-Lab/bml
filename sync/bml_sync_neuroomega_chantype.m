function sync = bml_sync_neuroomega_chantype(cfg, roi)

% BML_SYNC_NEUROOMEGA_CHANTYPE transfer sync info from one chantype to another
%
% Use as 
%   sync = bml_sync_neuroomega_chantype(cfg, roi)
%
% This function calculates synchronization rows for neuroomega channels,
% based on a sync channel. Normally neuroomega files are sync with the
% analog 2750Hz channel. This function creates registries for other
% channels (for example 'macro' and 'micro'), based on the synchronized channel. 
%
% roi - original sync table (normaly with chantype=analog)
% cfg.chantype      - char, new chantype 
% cfg.time_channel  - char, channel of new chantype
% cfg.filetype      - char, defaults to 'neuroomega.mat'
%
% returns an roi table with the new entries for neuroomega files.

filetype          = bml_getopt(cfg,'filetype','neuroomega.mat');
time_channel      = bml_getopt_single(cfg,'time_channel');
sync_time_channel = bml_getopt_single(cfg,'sync_time_channel','CANALOG_IN_1');
chantype          = bml_getopt(cfg,'chantype');

assert(~isempty(chantype),'chantype required');
assert(~isempty(time_channel),'time_channel required');

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
  if ismember(time_begin_var,fields(hdr.orig))
    coord.t1   = hdr.orig.(time_begin_var);
    coord.t2   = hdr.orig.(time_end_var);
    %(coord.t2 - coord.t1)*hdr.Fs == hdr.nSamples
  else
    error('%s not present as mat variable in %s. \nSpecify cfg.time_channel as one of %s',...
      time_begin_var,fullfile(row.folder{1},row.name{1}), strjoin(hdr.label));
  end
  if ismember(sync_time_begin_var,fields(hdr.orig))
  	orig_coord.t1 = hdr.orig.(sync_time_begin_var);
    orig_coord.t2 = hdr.orig.(sync_time_end_var);
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


