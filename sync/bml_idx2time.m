function time=bml_idx2time(cfg, idx)

% BML_IDX2TIME calculates samples midpoint times from a index vector and file coordinates
%
% Use as 
%   time=bml_idx2time(cfg, idx)
%
% where cfg is a configuration structure or roi table 
% cfg.t1
% cfg.s1
% cfg.t2
% cfg.s2
% cfg.nSamples - double: optional total number of samples in file
%
% if cfg has more than one row, (s1, s2) should be non-overlaping

if nargin~=2; error('unsupported call to bml_idx2time, see usage'); end

if istable(cfg)
  if height(cfg) > 1
    %dealing with split sync
    tmp = cfg(:,{'s1','s2'});
    tmp.Properties.VariableNames = {'starts','ends'};
    assert(isempty(bml_annot_overlap(tmp)),...
      "cfg table contains overlapping segments of samples");
    
    time = zeros(1,length(idx));
    for i=1:height(cfg)
      t1=cfg.t1(i);
      s1=cfg.s1(i);
      t2=cfg.t2(i);
      s2=cfg.s2(i);
      Fs=(s2-s1)/(t2-t1);  
      idx_filt = idx>=s1 & idx<=s2;
      time(idx_filt) = (1/Fs)*(idx(idx_filt)-0.5+(s2*t1-t2*s1)/(t2-t1));
    end

    return
  end
  cfg=table2struct(cfg);
end
  
%dealing with simple sync
t1=bml_getopt(cfg,'t1');
s1=bml_getopt(cfg,'s1');
t2=bml_getopt(cfg,'t2');
s2=bml_getopt(cfg,'s2');

Fs=(s2-s1)/(t2-t1);  
time = (1/Fs)*(idx-0.5+(s2*t1-t2*s1)/(t2-t1));

