function time=bml_idx2time(cfg, idx, skipFactor)

% BML_IDX2TIME calculates samples midpoint times from a index vector and file coordinates
%
% Use as 
%   time=bml_idx2time(cfg, idx)
%   time=bml_idx2time(cfg, idx, skipFactor)
%
% idx - numeric vector of indices to transform to time
% skipFactor - numeric, integer indicating skip factor as used by blackrock
%     NPMK package. Defaults to 1.
%
% where cfg is a configuration structure or roi table 
% cfg.t1
% cfg.s1
% cfg.t2
% cfg.s2
% cfg.nSamples - double: optional total number of samples in file
%
% if cfg has more than one row, (s1, s2) should be non-overlaping

pTT = 9; %pTT = pTimeTolerenace = - log10(timetol)

if nargin==2
  skipFactor=1;
elseif nargin==3
  skipFactor=round(skipFactor);
else
  error('unsupported call to bml_idx2time, see usage');
end

if istable(cfg)
  if height(cfg) > 1
    %dealing with split sync
    assert(isempty(bml_annot_overlap(cfg(:,{'s1','s2'}))),...
      "cfg table contains overlapping segments of samples");
    
    time = zeros(1,length(idx));
    for i=1:height(cfg)
      t1=round(cfg.t1(i),pTT);
      s1=cfg.s1(i);
      t2=round(cfg.t2(i),pTT);
      s2=cfg.s2(i);
      Fs=round((s2-s1)/round(t2-t1,pTT),pTT,'significat');  
      if skipFactor > 1
        s1=ceil(s1/skipFactor);
        s2=floor(s2/skipFactor);
        t1=t1+(skipFactor-1)*0.5/Fs;
        t2=t2-(skipFactor-1)*0.5/Fs;
        Fs = round((s2-s1)/round(t2-t1,pTT),pTT,'significat');  
      end
      idx_filt = idx>=s1 & idx<=s2;
      time(idx_filt) = double(idx(idx_filt))/Fs - 0.5/Fs + (s2*t1-t2*s1)/(s2-s1);
    end
    return
  end
  cfg=table2struct(cfg);
end
  
%dealing with simple sync
t1=round(bml_getopt(cfg,'t1'),pTT);
s1=bml_getopt(cfg,'s1');
t2=round(bml_getopt(cfg,'t2'),pTT);
s2=bml_getopt(cfg,'s2');
Fs = round((s2-s1)/round(t2-t1,pTT),pTT,'significant'); 
if skipFactor > 1
  s1=ceil(s1/skipFactor);
  s2=floor(s2/skipFactor);
  t1=t1+(skipFactor-1)*0.5/Fs;
  t2=t2-(skipFactor-1)*0.5/Fs;
  Fs = round((s2-s1)/round(t2-t1,pTT),pTT,'significant');
end
 
time = double(idx)/Fs - 0.5/Fs + (s2*t1-t2*s1)/(s2-s1);