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

t1=bml_getopt(cfg,'t1');
s1=bml_getopt(cfg,'s1');
t2=bml_getopt(cfg,'t2');
s2=bml_getopt(cfg,'s2');
nSamples=bml_getopt(cfg,'nSamples');

idx = round((t2*s1-s2*t1+(s2-s1).*time)/(t2-t1));

if any(idx<=0); error('negative index'); end
if ~isempty(nSamples)
  if any(idx>nSamples); error('index exceeds number of samples in file'); end
end
  
  
  

