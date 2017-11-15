function cropped = bml_crop(raw, starts, ends)

% BML_CROP returns a time-cropped raw
%
% Use as
%   croped = bml_crop(raw, starts, ends)
%   croped = bml_crop(cfg, raw)

if nargin==2
  cfg=raw;
  raw=starts;
  if istable(cfg)
    if height(cfg) > 1; error('cfg should be a 1 row table'); end
    cfg=table2struct(cfg);
  end
  starts = bml_getopt(cfg,'starts');
  ends = bml_getopt(cfg,'ends');
elseif nargin~=3
  error('invalid use of bml_crop');
end

if numel(raw.time) > 1; error('single trial continuous raw required'); end
nSamples = length(raw.time{1});

tc=[]; 
tc.s1=1; tc.s2=length(raw.time{1});
tc.t1=raw.time{1}(1); tc.t2=raw.time{1}(end);
[s,e]=bml_crop_idx(tc,starts,ends);

if s < 1; s=1; end
if e > nSamples; e = nSamples; end

cropped=raw;
cropped.trial{1} = raw.trial{1}(:,s:e);
cropped.time{1} = raw.time{1}(:,s:e);
cropped.sampleinfo = [s,e];


