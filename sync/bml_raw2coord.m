function coord = bml_raw2coord(raw,trial_idx)

% BML_RAW2COORD returns the time coordinated of the raw
%
% Use as 
%  coord = bml_raw2coord(raw)
%  coord = bml_raw2coord(raw,trial_idx)
%
% raw - FT_DATATYPE_RAW from which to extract coordinated
% trial_idx - integer index of the trial to extract. Defaults to 1. 
%
% The returned coord structure can be used in calls to bml_crop_idx

if ~exist('trial_idx','var')
  trial_idx = 1;
end

assert(all(ismember({'trial','time'},fields(raw))),"trial and time fields required in raw"); 
assert(length(trial_idx)==1,"Single trial index required");

if numel(raw.trial)<trial_idx
  warning("trial not present in raw");
end

coord=[];
coord.s1=1;
coord.s2=length(raw.time{trial_idx});
coord.t1=raw.time{trial_idx}(1);
coord.t2=raw.time{trial_idx}(end);
coord.nSamples=length(raw.time{trial_idx});



