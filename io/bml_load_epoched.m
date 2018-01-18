function [raw, loaded_epoch, file_raw_map] = bml_load_epoched(cfg)

% BML_LOAD_EPOCHED loads an epoched raw from one or more files
%
% Use as 
%   raw = bml_load_epoched(cfg)
%   [raw, file_raw_map] = bml_load_epoched(cfg)
%
% cfg.roi - ROI table with file synchronization information
% cfg.epoch - ANNOT table with epochs of interest. 
% cfg.electrode - ANNOT table with electrodes of interest. Must contain
%           'channel' and 'eletrode' variables.
% cfg.relabel - optinbal cellstr with new names of channels. 
% cfg.warn - logical indicating if warnings should be issued
%
% cfg... further arguments for BML_LOAD_CONTINUOUS 
% cfg.chantype
% cfg.channel
%
% --- resampling arguments ---
% cfg.resamplefs
% cfg.detrend 
% cfg.demean
% cfg.feedback
%
% returns a FT_DATATYPE_RAW with one trial per epoch. 
% file_raw_map is the mapping between files and samples in trials
% loaded_epoch are the efectively loaded epochs

roi        = bml_roi_table(bml_getopt(cfg,'roi'),'roi');
epoch      = bml_annot_table(bml_getopt(cfg,'epoch'),'epoch');
resamplefs = bml_getopt(cfg,'resamplefs');
detrend    = bml_getopt_single(cfg,'detrend','no');
demean     = bml_getopt_single(cfg,'demean','no');
feedback   = bml_getopt_single(cfg,'feedback','no');
electrode  = bml_annot_table(bml_getopt(cfg,'electrode'),'electrode');
relabel    = bml_getopt(cfg,'relabel');
warn       = bml_getopt(cfg,'warn',true);

cfg.roi = [];
cfg.epoch = [];
cfg.resamplefs=[];
cfg.detrend = [];
cfg.demean = [];
cfg.electrode = [];

cfg_resample = [];
if ~isempty(resamplefs)
  cfg_resample.resamplefs = resamplefs;
  cfg_resample.detrend = detrend;
  cfg_resample.demean = demean;
  cfg_resample.feedback = feedback;
end

assert(istable(epoch),"epoch required");
if ~ismember('epoch_id',epoch.Properties.VariableNames)
  epoch.epoch_id = epoch.id;
end

first = true;
raw = {};
file_raw_map = [];
loaded_epoch = table();

for i=1:height(epoch)
  fprintf("\n --- Loading epoch id %i (%i of %i) --- \n",epoch.id(i),i,height(epoch));
  
  i_loaded_epoch = epoch(i,:);
  cfg_keep_x = struct('keep','x');
  cfg.roi = bml_annot_intersect(cfg_keep_x, roi, epoch(i,:));
  assert(height(cfg.roi)>0,"No roi info for current epoch");
  cfg.roi = bml_sync_consolidate(cfg.roi);
  
  if ~isempty(electrode)
    %intersecting electrodes with rois
    cfg.electrode = bml_annot_intersect(cfg_keep_x, electrode, cfg.roi);
    %consolidating electrode rows corresponding to same epoched and channel
    %(for neuroomega files it can get split because of the chunking)
    if isempty(cfg.electrode)
      error("No electrodes left after intersection with roi. Check electrodes starts and ends.")
    end
    cfg.electrode=sortrows(cfg.electrode,...
      bml_getidx({'filetype','channel','starts'},cfg.electrode.Properties.VariableNames));
    cfg.electrode.id=(1:height(cfg.electrode))';
    cfg1=[];
    cfg1.criterion = @(x) (length(unique(x.filetype))==1) && ...
                          (length(unique(x.channel))==1) && ...
                          (abs((max(x.ends)-min(x.starts))-sum(x.duration))<10e-3);
    cfg.electrode=bml_annot_consolidate(cfg1,cfg.electrode);
  else
    cfg.electrode = [];
  end
  
  [i_raw,i_file_raw_map] = bml_load_continuous(cfg);
  i_file_raw_map.epoch_id(:) = epoch.id(i);
  
  if ~isempty(cfg_resample)
    i_raw = ft_resampledata(cfg_resample,i_raw);
  end
  
  if istrue(first) %initializing stuff
    if isempty(relabel)
      label = i_raw.label;
    else
      assert(numel(relabel)==numel(i_raw.label), "incorrect length for relabel");
      label = relabel;
      i_raw.label = label;
    end
    raw = {i_raw};
    i_file_raw_map.trial(:) = 1;
    file_raw_map = i_file_raw_map;
    if ismember('hdr',fields(i_raw))
      hdr=i_raw.hdr;
    else
      hdr=[];
    end
    i_loaded_epoch.id=1;
    first = false;
  else
    if ~isequal(label,i_raw.label)
      if istrue(warn) && isempty(relabel)
        warning('inconsistent channel names. Renaming.')
      end
      i_raw.label = label;
    end   
    raw = [raw, i_raw];
    i_trial = max(file_raw_map.trial)+1;
    i_file_raw_map.trial(:) = i_trial;
    file_raw_map = [file_raw_map; i_file_raw_map];
    i_loaded_epoch.id=i_trial;
  end
  
  loaded_epoch = [loaded_epoch; i_loaded_epoch];
end

cfg=[];
cfg.appenddim = 'rpt';
raw = ft_appenddata(cfg, raw{:});

if ~isempty(hdr)
  raw.hdr = hdr;
end

file_raw_map.id=[];
file_raw_map = bml_roi_table(file_raw_map);





