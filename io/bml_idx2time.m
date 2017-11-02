function time=bml_idx2time(cfg, idx)

% BML_IDX2TIME calculates samples midpoint times from a index vector and file coordinates
%
% Use as 
%   time=bml_idx2time(cfg, idx)
%
% where cfg is a configuration structure or roi table row
% cfg.t1
% cfg.s1
% cfg.t2
% cfg.s2
% cfg.nSamples - double: optional total number of samples in file

if nargin~=2; error('unsupported call to bml_idx2time, see usage'); end

if istable(cfg)
  if height(cfg) > 1; error('cfg should be a 1 row table'); end
  cfg=table2struct(cfg);
end
  
t1=bml_getopt(cfg,'t1');
s1=bml_getopt(cfg,'s1');
t2=bml_getopt(cfg,'t2');
s2=bml_getopt(cfg,'s2');
% nSamples=bml_getopt(cfg,'nSamples');

Fs=(s2-s1)/(t2-t1);

% % check consistency in bml_roi_table, overflow index useful for padding
% if any(idx<=0); error('negative index'); end
% if ~isempty(nSamples)
%   if any(idx>nSamples); error('index exceeds number of samples in file'); end
% end
  
time = (1/Fs)*(idx-0.5+(s2*t1-t2*s1)/(t2-t1));

