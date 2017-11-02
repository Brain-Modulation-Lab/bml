function padded = bml_pad(raw, starts, ends, padval)

% BML_PAD returns a padded version of the raw (crops if necessary)
%
% Use as
%   bml_pad(raw, starts, ends, padval)
%   bml_pad(cfg, raw)

if nargin==2
  cfg=raw;
  raw=starts;
  if istable(cfg)
    if height(cfg) > 1; error('cfg should be a 1 row table'); end
    cfg=table2struct(cfg);
  end
  starts = bml_getopt(cfg,'starts');
  ends = bml_getopt(cfg,'ends');
  padval = bml_getopt(cfg,'padval');
elseif nargin==3
  padval = 0;
elseif nargin ~=4
  error('invalid use of bml_pad');
end

if numel(raw.time) > 1; error('single trial continuous raw required'); end
nSamples = length(raw.time{1});

tc=[]; 
tc.s1=1; tc.s2=length(raw.time{1});
tc.t1=raw.time{1}(1); tc.t2=raw.time{1}(end);
[s,e]=bml_crop_idx(tc,starts,ends);

padded = bml_crop(raw,starts,ends);
if s<1 
  padded.trial{1} = padarray(padded.trial{1},[0 1-s],padval,'pre');
end
if e > nSamples
  padded.trial{1} = padarray(padded.trial{1},[0 e-nSamples],padval,'post');
end
padded.time{1} = bml_idx2time(tc,s:e);

padded.sampleinfo = [s,e];

