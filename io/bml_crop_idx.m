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

if istable(cfg)
  if height(cfg) > 1; error('cfg should be a 1 row table'); end
  cfg=table2struct(cfg);
end

if nargin==1
  starts=bml_getopt(cfg,'starts');
  ends=bml_getopt(cfg,'ends');
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
nSamples=bml_getopt(cfg,'nSamples');

Fs=(s2-s1)/(t2-t1);

tol=bml_getopt(cfg,'tol',1e-3/Fs);

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

% % check consistency in bml_roi_table, overflow indices useful for padding
% if starts_idx<=0; error('starts results in negative index'); end
% if ends_idx<=0; error('ends results in negative index'); end
% if ~isempty(nSamples)
%   if starts_idx>nSamples; error('starts index exceeds number of samples in file'); end
%   if ends_idx>nSamples; error('ends index exceeds number of samples in file'); end
% end
