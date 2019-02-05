function [p,max_delta_t,off_idx] = sync_cons_group(roi,timewarp,samplevar)

% SYNC_CONS_GROUP consolidates a single group of file coordinates

%doing linear fit to assess if consolidation is plausible
s = [roi.([samplevar '1']); roi.([samplevar '2'])];
t = [roi.t1; roi.t2];
if timewarp
  p = polyfit(s,t,1);
else
  assert(length(unique(roi.Fs))==1,"Inconsistent Fs");
  p1 = 1/unique(roi.Fs);
  p = [p1, mean(t-p1*s)];
end
tfit = polyval(p,s);
max_delta_t = max(abs(t - tfit));
off_idx = mod(find(abs(abs(t - tfit)-max_delta_t) < eps,1)-1,height(roi))+1;





  
  