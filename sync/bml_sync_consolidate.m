function consolidated = bml_sync_consolidate(cfg)

% BML_SYNC_CONSOLIDATE consolidates file synchronization chunks 
%
% Use as
%   consolidated = bml_sync_consolidate(cfg)
%   consolidated = bml_sync_consolidate(cfg.roi)
%
% cfg.roi - roi table with sync chunks to consolidate
% cfg.timetol - double: time tolerance allowed in consolidation. Defaults
%               to 1e-3
% cfg.contiguous - logical: should time contiguous files of the same type
%               be consolidated toghether. Defaults to true. 
% cfg.group - variable indicating grouping criteria. Entries of different groups 
%               are not consolidated together. Defaults to 'session_id'
% cfg.timewarp - boolean, indicates if linear time warping is allowed in
%               consolidation. If false, uses nominal Fs value in roi
%               table. Defaults to true.
% cfg.rowisfile - boolean, indicates if row refer to files. Defaults to true.
%
% If chunking for consolidation was done, each file can have several entries in the
% sync roi table. This function consolidates those entries into one per file.
% It does this by finding the sync curve that better fits all chunks. 

if istable(cfg)
  cfg = struct('roi',cfg);
end
roi             = bml_getopt(cfg,'roi');
timetol         = bml_getopt(cfg,'timetol',1e-3);
contiguous      = bml_getopt(cfg,'contiguous',true);
group           = bml_getopt_single(cfg,'group','session_id');
timewarp        = bml_getopt(cfg,'timewarp',true);
rowisfile       = bml_getopt(cfg,'rowisfile',true);
group_specified = ismember("group",fieldnames(cfg));

REQUIRED_VARS = {'folder','name','chantype','filetype'};
if ~all(ismember(REQUIRED_VARS,roi.Properties.VariableNames))
  if rowisfile
    error('Variables %s required',strjoin(REQUIRED_VARS))
  else
    for i=1:length(REQUIRED_VARS)
      roi.(REQUIRED_VARS{i})=repmat({'NA'},height(roi),1);
    end
  end
end

roi = bml_roi_table(roi);

% REQUIRED_VARS = {'s1','t1','s2','t2','nSamples','Fs'};
% assert(all(ismember(REQUIRED_VARS,roi.Properties.VariableNames)),...
%   'Variables %s required',strjoin(REQUIRED_VARS))

roi.fullfile = fullfile(roi.folder,roi.name);
if ismember(group,roi.Properties.VariableNames)
  if group_specified
    fprintf("grouping by %s \n",group);
  end
  if isnumeric(roi.(group))
    roi.fullfile = strcat(roi.fullfile,'_',num2str(roi.(group)));
  else
    roi.fullfile = strcat(roi.fullfile,'_',roi.(group));
  end
end
roi.sync_id = roi.id;
uff = unique(roi.fullfile); %unique fullfile
consolidated = table();

%consolidating several entries for the same file. 
for i_uff=1:length(uff)
  i_roi = roi(strcmp(roi.fullfile,uff(i_uff)),:);
  if height(i_roi)>1

    %doing linear fit to assess if consolidation is plausible
    s = [i_roi.s1; i_roi.s2];
    t = [i_roi.t1; i_roi.t2];
    if timewarp
      p = polyfit(s,t,1);
    else
      assert(length(unique(i_roi.Fs))==1,"Inconsistent Fs");
      p1 = 1/unique(i_roi.Fs);
      p = [p1, mean(t-p1*s)];
    end
    tfit = polyval(p,s);
    
    max_delta_t = max(abs(t - tfit));
    if max_delta_t <= timetol %consolidating
      consrow = i_roi(1,:);
      consrow.starts = min(i_roi.starts);
      consrow.ends = max(i_roi.ends);
      consrow.s1 = min(i_roi.s1);
      consrow.s2 = max(i_roi.s2);
      consrow.t1 = polyval(p,consrow.s1);
      consrow.t2 = polyval(p,consrow.s2);
      if ismember('warpfactor',i_roi.Properties.VariableNames)
        consrow.warpfactor = 1/(consrow.Fs * p(1));
      end
      i_roi = consrow;      
    else  
      error('can''t consolidate within tolerance. Max delta t %f > %f',max_delta_t,timetol)
    end
  end
  consolidated = [consolidated; i_roi];
end

consolidated.id=[];
roi.fullfile=[];
consolidated = bml_roi_table(consolidated);

%consolidating several time contiguos files together
if contiguous
  roi = consolidated;
  consolidated = table();
  roi.filetype_chantype = strcat(roi.filetype,roi.chantype,num2str(roi.Fs));
  ufc = unique(roi.filetype_chantype);
  for i_ufc=1:length(ufc)
  	i_roi = roi(strcmp(roi.filetype_chantype,ufc(i_ufc)),:);
    if  height(i_roi)>1 && length(unique(i_roi.name))<=1
      %probably the first consolidation failed. Returning with a warning
      error('multiple chunks for single file after per file consolidation');
      consolidated = bml_roi_table(roi);
      return
    end
    %detecting contiguos stretches
    cfg=[];
    cfg.criterion = @(x) abs(sum(x.duration)-max(x.ends)+min(x.starts)) < height(x)*timetol;
    i_roi_cont = bml_annot_consolidate(cfg,i_roi);   
    
    for j=1:height(i_roi_cont)
    	i_roi_cont_j = i_roi(i_roi.id>=i_roi_cont.id_starts(j) & i_roi.id<=i_roi_cont.id_ends(j),:);
    
      if height(i_roi_cont_j)>1
        
        left_complete = i_roi_cont_j.starts(1)<=i_roi_cont_j.t1(1);
        right_complete = i_roi_cont_j.ends(end)>=i_roi_cont_j.t2(end);
        
        %calculating raw samples of contiguous file
        cs = cumsum(i_roi_cont_j.s2-i_roi_cont_j.s1) + i_roi_cont_j.s1(1);
        cs = cs + (0:(height(i_roi_cont_j)-1))';
        cs = [0; cs(1:end-1)];
        i_roi_cont_j.raw1 = i_roi_cont_j.s1 + cs;
        i_roi_cont_j.raw2 = i_roi_cont_j.s2 + cs;
        
        %doing linear fit to asses if consolidation is plausible
        s = [i_roi_cont_j.raw1; i_roi_cont_j.raw2];
        t = [i_roi_cont_j.t1; i_roi_cont_j.t2];
        %plot(s,t,'o')
        if timewarp
          p = polyfit(s,t,1);
        else
          assert(length(unique(i_roi_cont_j.Fs))==1,"Inconsistent Fs");
          p1 = 1/unique(i_roi_cont_j.Fs);
          p = [p1, mean(t-p1*s)];
        end
        tfit = polyval(p,s);
      
        max_delta_t = max(abs(t - tfit));
        if max_delta_t <= timetol %consolidating
          i_roi_cont_j.t1 = polyval(p,i_roi_cont_j.raw1);
          i_roi_cont_j.t2 = polyval(p,i_roi_cont_j.raw2);
          if ismember('warpfactor',i_roi_cont_j.Properties.VariableNames)
            i_roi_cont_j.warpfactor = 1 ./ (i_roi_cont_j.Fs .* p(1));
          end
        else  
          error('can''t consolidate within tolerance. Max delta t %f > %f',max_delta_t,timetol);
        end
        i_roi_cont_j.raw1=[];
        i_roi_cont_j.raw2=[];          
        
        %adjusting starts and ends to take to confluence
        if left_complete
          i_roi_cont_j.starts(1) = i_roi_cont_j.t1(1) - 0.5/i_roi_cont_j.Fs(1);
        end
        for i=1:(height(i_roi_cont_j)-1)
          i_roi_cont_j.ends(i)     = (i_roi_cont_j.t2(i) + i_roi_cont_j.t1(i+1))/2;
          i_roi_cont_j.starts(i+1) = (i_roi_cont_j.t2(i) + i_roi_cont_j.t1(i+1))/2;        
        end
        if right_complete
          i_roi_cont_j.ends(1) = i_roi_cont_j.t2(1) + 0.5/i_roi_cont_j.Fs(1);
        end
    
        consolidated = [consolidated; i_roi_cont_j];
      else
        consolidated = [consolidated; i_roi_cont_j];
      end
    end
  end
end

consolidated = bml_roi_table(consolidated);

