function [starts_idx,ends_idx] = bml_crop_idx_valid(cfg, varargin)

% BML_CROP_IDX_VALID calculates valid sample indices for a time window and file coordinates
%
% Same as BML_CROP_IDX but bounds the starts and ends sample to the 1 and
% nSample if necesarry
%
% Use as 
%   [starts_idx,ends_idx] = bml_crop_idx_valid(cfg)
%   [starts_idx,ends_idx] = bml_crop_idx_valid(cfg, starts, ends)
%   [starts_idx,ends_idx] = bml_crop_idx_valid(cfg, starts, [], samples)
%   [starts_idx,ends_idx] = bml_crop_idx_valid(cfg, [], ends, samples)
%
% where cfg is a configuration structure or roi table row
% cfg.starts
% cfg.ends
% (cfg.samples)
% cfg.t1
% cfg.s1
% cfg.t2
% cfg.s2
% cfg.nSamples - double: total number of samples in file
% cfg.tol - double: tolerance. Defaults to 1e-3/Fs. 
%
% if starts and ends are given (3 argument call) the values of cfg are
% ignored

nSamples=bml_getopt(cfg,'nSamples',[]);
assert(~isempty(nSamples),'cfg.nSamples reuired');

[starts_idx,ends_idx] = bml_crop_idx(cfg, varargin{:});

% bounding to begging and end of file
if starts_idx<1
  starts_idx=1;
elseif starts_idx>nSamples
   error('starts index exceeds number of samples in file');
end
if ends_idx>nSamples
  ends_idx=nSamples;
elseif ends_idx<=0
  error('ends index before first sample');
end
