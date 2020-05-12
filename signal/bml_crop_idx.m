function [starts_idx,ends_idx] = bml_crop_idx(cfg, starts, ends, samples)

% BML_CROP_IDX calculates sample indices for a time window and file coordinates
%
% Use as 
%   [starts_idx,ends_idx] = bml_crop_idx(cfg)
%   [starts_idx,ends_idx] = bml_crop_idx(cfg, starts, ends)
%   [starts_idx,ends_idx] = bml_crop_idx(cfg, starts, [], samples)
%   [starts_idx,ends_idx] = bml_crop_idx(cfg, [], ends, samples)
%
% where cfg is a configuration structure or roi table row
% cfg.starts
% cfg.ends
% (cfg.samples)
% cfg.t1
% cfg.s1
% cfg.t2
% cfg.s2
% cfg.tol - double: tolerance. Defaults to 1e-3/Fs. 
% cfg.nSamples - double: optional total number of samples in file
%
% if starts and ends are given (3 argument call) the values of cfg are
% ignored

% if istable(cfg)
%   if height(cfg) > 1; error('cfg should be a 1 row table'); end
%   cfg=table2struct(cfg);
% end

pTT = 9; %pTT = pTimeTolerenace = - log10(timetol)

if nargin==1
  starts=round(bml_getopt(cfg,'starts'),pTT);
  ends=round(bml_getopt(cfg,'ends'),pTT);
  samples=bml_getopt(cfg,'samples');
elseif nargin==3
  samples=[];
elseif nargin~=4
  error('unsupported call to bml_crop_idx, see usage');
end
  
if ~isempty(starts) + ~isempty(ends) + ~isempty(samples) ~= 2
  error('two of the three following parameters are required: ''starts'', ''ends'', ''samples'''); 
end

t1=bml_getopt(cfg,'t1');
s1=bml_getopt(cfg,'s1');
t2=bml_getopt(cfg,'t2');
s2=bml_getopt(cfg,'s2');

Fs=(s2-s1)/round(t2-t1,pTT);

tol=bml_getopt(cfg,'tol',1e-2/Fs);

if ~isempty(starts)
  starts_idx = round((t2*s1-s2*t1)/(t2-t1)+Fs*starts+tol);
  %starts_idx = ceil(0.5+(t2*s1-s2*t1)/(t2-t1)+Fs*starts);
end

if isempty(ends)
  ends_idx = starts_idx + samples; 
else
  ends_idx = round((t2*s1-s2*t1)/(t2-t1)+Fs*ends-tol);
  %ends_idx = floor(0.5+(t2*s1-s2*t1)/(t2-t1)+Fs*ends);
end

if isempty(starts) 
  starts_idx = ends_idx - samples;
end

