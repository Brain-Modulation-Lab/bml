function idx=bml_time2idx(cfg, time)

% BML_TIME2IDX calculates sample indices from a time vector and file coordinates
%
% Use as 
%   idx=bml_time2idx(cfg, time)
%
% where cfg is a configuration structure or roi table row
% cfg.t1
% cfg.s1
% cfg.t2
% cfg.s2
% cfg.nSamples - double: optional total number of samples in file
%

if nargin~=2; error('unsupported call to bml_time2idx, see usage'); end

if istable(cfg)
  if height(cfg) > 1; error('cfg should be a 1 row table'); end
  cfg=table2struct(cfg);
end
  
t1=bml_getopt(cfg,'t1');
s1=bml_getopt(cfg,'s1');
t2=bml_getopt(cfg,'t2');
s2=bml_getopt(cfg,'s2');
nSamples=bml_getopt(cfg,'nSamples');

Fs=(s2-s1)/(t2-t1);

idx = round((t2*s1-s2*t1)/(t2-t1)+Fs*time);

if any(idx<=0); error('negative index'); end
if ~isempty(nSamples)
  any(idx>nSamples); error('index exceeds number of samples in file'); end
end
  
  
  

