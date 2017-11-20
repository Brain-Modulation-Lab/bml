function consolidated = bml_sync_consolidate(cfg)

% BML_SYNC_CONSOLIDATE consolidates file chunks synchronizations
%
%
% cfg.roi - roi table with sync chunks to consolidate
% cfg.timetol - double: time tolerance allowed in consolidation. Defaults
%               to 1e-2
%
% If chunking for consolidation, each file can have several entries in the
% sync output. This function consolidates those entries into one per file

if istable(cfg)
  cfg = struct('roi',cfg);
end
roi       = bml_getopt(cfg,'roi');
timetol   = bml_getopt(cfg,'timetol',1e-2);

roi.fullfile = fullfile(roi.folder,roi.name);
roi.sync_id = roi.id;
uff = unique(roi.fullfile); %unique fullfile
consolidated = table();

for i_uff=1:length(uff)
  i_roi = roi(strcmp(roi.fullfile,uff(i_uff)),:);
  if height(i_roi)>1

    %keyboard
    %for i=1:height(i_roi)
    %  plot([i_roi.s1(i) i_roi.s2(i)],[i_roi.t1(i) i_roi.t2(i)])
    %end

    %doing linear fit to asses if consolidation is plausible
    s = [i_roi.s1; i_roi.s2];
    t = [i_roi.t1; i_roi.t2];
    p = polyfit(s,t,1);
    tfit = polyval(p,s);
    
    if max(abs(t - tfit)) <= timetol %consolidating
      consrow = i_roi(1,:);
      consrow.starts = min(i_roi.starts);
      consrow.ends = max(i_roi.ends);
      consrow.s1 = min(i_roi.s1);
      consrow.s2 = max(i_roi.s2);
      consrow.t1 = polyval(p,consrow.s1);
      consrow.t2 = polyval(p,consrow.s2);
      if ismember('warpfactor',i_roi.Properties.VariableNames)
        consrow.warpfactor = consrow.Fs * p(1);
      end
      i_roi = consrow;      
    end
  end
  consolidated = [consolidated; i_roi];
end

consolidated.id=[];
consolidated = bml_roi_table(consolidated);

