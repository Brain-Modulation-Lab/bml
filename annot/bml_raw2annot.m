function annot = bml_raw2annot(cfg, raw)

% BML_RAW2ANNOT creates an annotation table from a raw
%
% Use as
%   annot = bml_raw2annot(raw)
%   annot = bml_raw2annot(cfg, raw)
%
% cfg.per_label = bool, defults to false. If true, a row for every label
%   and every trial will be created, and the variable 'label' will be
%   included in the output
%
% raw - FT_DATATYPE_RAW
%
% returns an ANNOT table with variables
%   'id' corresponds to the trial
%   'starts' time represented by the trial
% 	'ends' time represented by the trial
%   'duration' in seconds
%   'trial' 
%   's1' double, first sample sync coord
%   't1' double, time of first sample sample sync coord
%   's2' double, second sample sync coord
%   't2' double, time of second sample sample sync coord
%   'Fs' double, sampling rate
%   'nSamples' double, number of samples in raw
%   ('label') string with label name, present if cfg.per_label==true


if nargin == 1
  raw = cfg;
  cfg = [];
  description = inputname(1);
elseif nargin == 2
  description = inputname(2);
else
  error('Incorrect usage of bml_raw2annot')
end

per_label = bml_getopt(cfg,'per_label',false);

if per_label
  labels = raw.label;
else
  labels = {'roi'};
end

annot = table();
for l=1:numel(labels)
  label = labels(l);
  annot_l=table();
  for i=1:numel(raw.trial)
    trial = i;
    nSamples = size(raw.trial{i},2);

    if ismember('fsample',fields(raw))
      Fs = raw.fsample;
    else
      Fs = round(1/mean(diff(raw.time{i})),9,'significant');
    end

    s1 = 1;
    s2 = nSamples;     
    t1 = raw.time{i}(1);
    t2 = raw.time{i}(end);
    starts = t1 - 0.5/Fs;
    ends = t2 + 0.5/Fs;

    annot_l = [annot_l; table(starts,ends,trial,s1,t1,s2,t2,Fs,nSamples,label)];
  end
  annot = [annot; annot_l];
end

if ~per_label
  annot.label = [];
end

annot = bml_annot_table(annot,[],description);
