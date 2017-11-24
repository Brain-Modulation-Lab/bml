function coord = bml_raw2coord(raw)

% BMLRAW2COORD returns the time coordinated of the raw
%
% Use as 
%  coord = bml_raw2coord(raw)
%
% The returned coord structure can be used in calls to bml_crop_idx

assert(all(ismember({'trial','time'},fields(raw))),"trial and time fields required in raw"); 

if numel(raw.trial)>1
  warning("only first trial of raw considered");
end

coord=[];
coord.s1=1;
coord.s2=length(raw.time{1});
coord.t1=raw.time{1}(1);
coord.t2=raw.time{1}(end);
coord.nSamples=length(raw.time{1});



