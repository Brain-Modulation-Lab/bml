function [consrow, conserr] = sync_cons_group_partial(roi,timewarp,samplevar,timetol)

n = height(roi);
g = roi.id;
ug = unique(g);
min_delta_t = 0;

while min_delta_t < timetol && length(ug)>1
  neighbor_delta_t = nan(1,length(ug)-1);
  for i_ug=1:(length(ug)-1)
    el = find(g==ug(i_ug) | g==ug(i_ug+1));
    [~,max_delta_t,~] = sync_cons_group(roi(el,:),timewarp,samplevar);
    neighbor_delta_t(i_ug) = max_delta_t;
  end
  [min_delta_t, I] = min(neighbor_delta_t);
  if min_delta_t < timetol
    g(g==ug(I+1))=ug(I);
  end
  ug = unique(g);
end

consrow = table();
for i_ug=1:length(ug)
  i_roi = roi(g==ug(i_ug),:);
  [p,max_delta_t,~] = sync_cons_group(i_roi,timewarp,samplevar); 
  i_consrow = i_roi(1,:);
  i_consrow.starts = min(i_roi.starts);
  i_consrow.ends = max(i_roi.ends);
  i_consrow.([samplevar '1']) = min(i_roi.([samplevar '1']));
  i_consrow.([samplevar '2']) = max(i_roi.([samplevar '2']));
  i_consrow.t1 = polyval(p,i_consrow.([samplevar '1']));
  i_consrow.t2 = polyval(p,i_consrow.([samplevar '2']));
  i_consrow.cons_t_err = max_delta_t;
  i_consrow.cons_n = height(i_roi);
  if ismember('warpfactor',i_roi.Properties.VariableNames)
    i_consrow.warpfactor = 1/(i_consrow.Fs * p(1));
  end
  consrow = [consrow; i_consrow];      
end
consrow = bml_annot_table(consrow);

if length(ug)>1
  conserr=table(consrow.id(1:(end-1)),consrow.id(2:end),neighbor_delta_t',...
    'VariableNames',{'id1','id2','cons_t_err'});
else
  conserr=table();
end


    
    