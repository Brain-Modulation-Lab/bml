function [padded, presamples, postsamples] = bml_pad(raw, starts, ends, padval)

% BML_PAD returns a padded version of the raw (crops if necessary)
%
% Use as
%   padded = bml_pad(raw, starts, ends, padval)
%   padded = bml_pad(cfg, raw)
%   [padded, presamples, postsamples] = bml_pad(___)
%
% raw     - FT_DATATYPE_RAW to be padded and/or cropped
% starts  - double: global time at which to start
% ends    - double: global time at which to end
% padval  - double: value used for padding, defaults to zero
%
% padded  - FT_DATATYPE_RAW: padded version of raw
% presamples - integer: number of padval samples added at the begging 
% postsamples - integer: number of padval samples added at the end          

if nargin==2
  cfg=raw;
  raw=starts;
  if istable(cfg)
    %if height(cfg) > 1; error('cfg should be a 1 row table'); end
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

if numel(raw.time) == 1
  % case single trial. 
  nSamples = length(raw.time{1});

  % tc=[]; 
  % tc.s1=1; tc.s2=length(raw.time{1});
  % tc.t1=raw.time{1}(1); tc.t2=raw.time{1}(end);
  tc = bml_raw2coord(raw);
  [s,e]=bml_crop_idx(tc,starts,ends);

  padded = bml_crop(raw,starts,ends);
  presamples = max([1-s, 0]);
  postsamples = max([e-nSamples, 0]);

  if presamples>0 
    padded.trial{1} = padarray(padded.trial{1},[0 presamples],padval,'pre');
  end
  if postsamples > 0
    padded.trial{1} = padarray(padded.trial{1},[0 postsamples],padval,'post');
  end
  padded.time{1} = bml_idx2time(tc,s:e);

  padded.sampleinfo = [s,e];

else % case multiple trials
	padded = bml_crop(raw,starts,ends);
  for i=1:numel(raw.time)
    nSamples = length(raw.time{i});
    tc = bml_raw2coord(raw, i);
    [s,e]=bml_crop_idx(tc,starts(i),ends(i));
    presamples = max([1-s, 0]);
    postsamples = max([e-nSamples, 0]);

    if presamples>0 
      padded.trial{i} = padarray(padded.trial{i},[0 presamples],padval,'pre');
    end
    if postsamples > 0
      padded.trial{i} = padarray(padded.trial{i},[0 postsamples],padval,'post');
    end
    padded.time{i} = bml_idx2time(tc,s:e);

    padded.sampleinfo(i,:) = [s,e];
  end

end
    
    
