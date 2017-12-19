function [raw, file_raw_map] = bml_load_epoched(cfg)

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
% cfg.channel
% cfg.chantype
% cfg... further arguments for BML_LOAD_CONTINUOUS 
%
% --- resampling arguments ---
% cfg.resamplefs
% cfg.detrend 
% cfg.demean
% cfg.feedback

roi        = bml_roi_table(bml_getopt(cfg,'roi'),'roi');
epoch      = bml_annot_table(bml_getopt(cfg,'epoch'),'epoch');
resamplefs = bml_getopt(cfg,'resamplefs');
detrend    = bml_getopt_single(cfg,'detrend','no');
demean     = bml_getopt_single(cfg,'demean','no');
feedback   = bml_getopt_single(cfg,'feedback','no');
electrode  = bml_annot_table(bml_getopt(cfg,'electrode'),'electrode');

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

first = true;
raw = {};
file_raw_map = [];
for i=1:height(epoch)
  cfg_keep_x = struct('keep','x');
  cfg.roi = bml_annot_intersect(cfg_keep_x, roi, epoch(i,:));
  
  if ~isempty(electrode)
    cfg.electrode = bml_annot_intersect(cfg_keep_x, electrode, cfg.roi);
  else
    cfg.electrode = [];
  end
  
  [i_raw,i_file_raw_map] = bml_load_continuous(cfg);
  i_file_raw_map.epoch_id(:) = epoch.id(i);
  
  if ~isempty(cfg_resample)
    i_raw = ft_resampledata(cfg_resample,i_raw);
  end
  
  if istrue(first)
    raw = {i_raw};
    i_file_raw_map.trial(:) = 1;
    file_raw_map = i_file_raw_map;
    first = false;
  else
    raw = [raw, i_raw];
    i_file_raw_map.trial(:) = max(file_raw_map.trial)+1;
    file_raw_map = [file_raw_map; i_file_raw_map];
  end
end

cfg=[];
cfg.appenddim = 'rpt';
raw = ft_appenddata(cfg, raw{:});

file_raw_map.id=[];
file_raw_map = bml_roi_table(file_raw_map);





