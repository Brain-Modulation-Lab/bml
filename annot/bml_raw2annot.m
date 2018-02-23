function annot = bml_raw2annot(raw)

% BML_RAW2ANNOT creates an annotation table from a raw
%
% raw - FT_DATATYPE_RAW
%
% returns an ANNOT table with variables
%   'id' corresponds to the trial
%   'starts' time represented by the trial
% 	'ends' time represented by the trial
%   'duration' in seconds
%   's1' double, first sample sync coord
%   't1' double, time of first sample sample sync coord
%   's2' double, second sample sync coord
%   't2' double, time of second sample sample sync coord
%   'Fs' double, sampling rate
%   'nSamples' double, number of samples in raw

annot = table();
for i=1:numel(raw.trial)
  id = i;
  nSamples = size(raw.trial{i},2);
  
  if ismember('fsample',fields(raw))
    Fs = raw.fsample;
  else
    Fs = round(1/mean(diff(raw.time{i})),9,'significant');
  end
  
%   if ismember('sampleinfo',fields(raw))
%     s1 = raw.sampleinfo(i,1);
%     s2 = raw.sampleinfo(i,2);
%   else
%     s1 = 1;
%     s2 = nSamples;   
%   end
  s1 = 1;
  s2 = nSamples;     

  t1 = raw.time{i}(1);
  t2 = raw.time{i}(end);
  
  starts = t1 - 0.5/Fs;
  ends = t2 + 0.5/Fs;
  
  annot = [annot; table(id,starts,ends,s1,t1,s2,t2,Fs,nSamples)];
  
end

annot = bml_annot_table(annot,inputname(1));
