function cropped = bml_crop(raw, starts, ends)

% BML_CROP returns a time-cropped raw [INTERNAL]
%
% Use as
%   croped = bml_crop(raw, starts, ends)
%   croped = bml_crop(cfg, raw)
%
% raw - FT_DATATYPE_RAW data to be cropped
% starts - double array: time in seconds for begging of each trial
%          length of starts should coincide with number of trials of raw
% ends - double array: time in seconds for the end of each trial 
%          length of ends should coincide with number of trials of raw
%
% This function was designed to crop continuous files and is mailny used as
% an internal function. Use BML_REDEFINETRIAL to re-epoch a RAW. 

if nargin==2
  cfg=raw;
  raw=starts;
  if istable(cfg)
    starts = cfg.starts;
    ends = cfg.ends;
  elseif isstruct(cfg)
    starts = bml_getopt(cfg,'starts');
    ends = bml_getopt(cfg,'ends');    
  end
elseif nargin~=3
  error('invalid use of bml_crop');
end

assert(length(starts)==numel(raw.trial),...
  "length of starts (%i) doesn't match number of trials (%i)",length(starts),numel(raw.trial));
assert(length(ends)==numel(raw.trial),...
  "length of ends (%i) doesn't match number of trials (%i)",length(ends),numel(raw.trial));

cropped=raw;
for i=1:numel(raw.trial)
  nSamples = length(raw.time{i});

  tc=bml_raw2coord(raw,i);
  [s,e]=bml_crop_idx(tc,starts(i),ends(i));

  if s < 1; s=1; end
  if e > nSamples; e = nSamples; end

  cropped.trial{i} = raw.trial{i}(:,s:e);
  cropped.time{i} = raw.time{i}(:,s:e);
  cropped.sampleinfo(i,:) = [s,e];
end

