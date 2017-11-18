function consolidated_sync = bml_sync_consolidate(cfg)

% BML_SYNC_CONSOLIDATE consolidates file chunks synchronizations
%
%
% cfg.roi
%
% If chunking for consolidation, each file can have several entries in the
% sync output. This function consolidates those entries into one per file

if istable(cfg)
  cfg = struct('roi',cfg);
end
roi = bml_getopt(cfg,'roi');

roi.fullfile = fullfile(roi.folder,roi.name);
roi.sync_id = roi.id;
uff = unique(roi.fullfile); %unique fullfile
consolidated_sync = table();

for i_uff=1:length(uff)
  i_roi = roi(strcmp(roi.fullfile,uff(i_uff)),:);
  if height(i_roi)>1
    %ToDo: improve consolidation algorithm
    consrow = i_roi(1,:);
    consrow.starts = min(i_roi.starts);
    consrow.ends = max(i_roi.ends);
    consrow.s1 = min(i_roi.s1);
    consrow.s2 = max(i_roi.s2);
    consrow.t1 = min(i_roi.t1);
    consrow.t2 = max(i_roi.t2);
    if ismember('warpfactor',i_roi.Properties.VariableNames)
      consrow.warpfactor = sum(i_roi.warpfactor .* i_roi.duration)/sum(i_roi.duration);
    end
    i_roi = consrow;    
  end
  consolidated_sync = [consolidated_sync; i_roi];
end

consolidated_sync.id=[];
consolidated_sync = bml_roi_table(consolidated_sync);

