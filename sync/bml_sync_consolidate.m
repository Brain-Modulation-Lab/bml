function consolidated = bml_sync_consolidate(cfg)

% BML_SYNC_CONSOLIDATE consolidates synchronization chunks 
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
% cfg.timetol_contiguous - double: time tolerance in seconds by which to
%               detect contiguous files. Defaults to 1e-3.
% cfg.group - variable indicating grouping criteria. Entries of different groups 
%               are not consolidated together. Defaults to 'session_id'
% cfg.timewarp - boolean, indicates if linear time warping is allowed in
%               consolidation. If false, uses nominal Fs value in roi
%               table. Defaults to true.
% cfg.rowisfile - boolean, indicates if row refer to files. Defaults to true.
% cfg.partial   - boolean, indicates if partial consolidation is allowed.
%               Defaults to false. 
% cfg.plot_diagnostic - boolean, indicates if per group matrix of pariwise
%               consolidation residual should be plotted.
%               usefull for rouge chunk identification. Defaults to false.
%
% If chunking for consolidation was done, each file can have several entries in the
% sync roi table. This function consolidates those entries into one per file.
% It does this by finding the sync line that better fits all chunks. This function
% alson consolidates time contiguos files of the same filetype. 

if istable(cfg)
  cfg = struct('roi',cfg);
end
roi                = bml_getopt(cfg,'roi');
timetol            = bml_getopt(cfg,'timetol',1e-3);
timetol_contiguous = bml_getopt(cfg,'timetol_contiguous',1e-3);
contiguous         = bml_getopt(cfg,'contiguous',true);
timewarp           = bml_getopt(cfg,'timewarp',true);
rowisfile          = bml_getopt(cfg,'rowisfile',true);
partial            = bml_getopt(cfg,'partial',false);
plot_diagnostic    = bml_getopt(cfg,'plot_diagnostic',false);

group_specified = ismember("group",fieldnames(cfg));
if group_specified 
  if ~isempty(cfg.group)
    group = bml_getopt_single(cfg,'group');
  else
    group = [];
  end
else
  group = bml_getopt_single(cfg,'group','session_id');
end

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

REQUIRED_VARS = {'s1','t1','s2','t2','nSamples','Fs'};
assert(all(ismember(REQUIRED_VARS,roi.Properties.VariableNames)),...
  'Variables %s required',strjoin(REQUIRED_VARS))

roi.fullfile = fullfile(roi.folder,roi.name);

%dealing with consolidation groups (usually sessions)
if ~isempty(group) && ismember(group,roi.Properties.VariableNames)
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

    if plot_diagnostic
      delta_t_M = sync_cons_group_pairwise(i_roi,timewarp,'s');
      figure();
      image(delta_t_M,'CDataMapping','scaled');
      xticks(1:height(i_roi));
      yticks(1:height(i_roi));
      xticklabels(i_roi.id);
      yticklabels(i_roi.id);
      title(regexprep(uff{i_uff}, '\\', '\\\\'));
      colorbar;
    end
    
    %doing linear fit to assess if consolidation is plausible
    [consrow,conserr] = sync_cons_group_partial(i_roi,timewarp,'s',timetol);
    
    if height(consrow)>1
      fprintf(['\nGroup ' regexprep(uff{i_uff}, '\\', '\\\\') '\n']);
      consrow(:,{'id','starts','duration','cons_n','cons_t_err'})
      conserr(:,{'id1','id2','cons_t_err'})
      if ~partial
        error('can''t consolidate within tolerance. Max delta t %f > %f',...
          max(conserr.cons_t_err),timetol)
      end
    elseif height(consrow)==0
      error('empty group');
    else
      %managed to consolidate within tolerance, continue
    end
    i_roi = consrow;
  else
    i_roi.cons_t_err=0;
    i_roi.cons_n=1;
  end
  consolidated = [consolidated; i_roi];
end


if ~isempty(consolidated)
  consolidated.id=[];
  consolidated = bml_roi_table(consolidated);
else
  keyboard
end
roi.fullfile=[];

%consolidating several time contiguos files together
if contiguous
  
  roi = consolidated;
  consolidated = table();
  roi.filetype_chantype = strcat(roi.filetype,roi.chantype,num2str(roi.Fs));
  
  %dealing with consolidation groups (usually sessions)
  if ismember(group,roi.Properties.VariableNames)
    if isnumeric(roi.(group))
      roi.filetype_chantype = strcat(roi.filetype_chantype,'_',num2str(roi.(group)));
    else
      roi.filetype_chantype = strcat(roi.filetype_chantype,'_',roi.(group));
    end
  end
  
  ufc = unique(roi.filetype_chantype);
  for i_ufc=1:length(ufc)
  	i_roi = roi(strcmp(roi.filetype_chantype,ufc(i_ufc)),:);
    if height(i_roi)>1 && length(unique(i_roi.name))<=1 
      if partial
        consolidated = [consolidated; i_roi];
        continue
      else
        error('multiple chunks for single file (and group) after per file consolidation');
      end
    end
    
    %detecting time contiguos stretches
    cfg=[];
    cfg.criterion = @(x) abs(sum(x.duration)-max(x.ends)+min(x.starts)) < height(x)*timetol_contiguous;
    i_roi_cont = bml_annot_consolidate(cfg,bml_roi_confluence(i_roi));   
    
    for j=1:height(i_roi_cont)
    	i_roi_cont_j = i_roi(i_roi.id>=i_roi_cont.id_starts(j) & i_roi.id<=i_roi_cont.id_ends(j),:);
    
      if height(i_roi_cont_j)>1
        
        left_complete = i_roi_cont_j.starts(1)<=i_roi_cont_j.t1(1);
        right_complete = i_roi_cont_j.ends(end)>=i_roi_cont_j.t2(end);

        %calculating raw samples of contiguous file
        i_roi_cont_j = s2raw(i_roi_cont_j);
        
%         if plot_diagnostic
%           delta_t_M = sync_cons_group_pairwise(i_roi_cont_j,timewarp,'raw');
%           figure();
%           image(delta_t_M,'CDataMapping','scaled');
%           xticks(1:height(i_roi_cont_j));
%           yticks(1:height(i_roi_cont_j));
%           xticklabels(i_roi_cont_j.id);
%           yticklabels(i_roi_cont_j.id);
%           colorbar;
%         end

        %doing linear fit to asses if consolidation is plausible
        [p,max_delta_t,off_idx] = sync_cons_group(i_roi_cont_j,timewarp,'raw');
        
        if max_delta_t <= timetol %consolidating
          i_roi_cont_j.t1 = polyval(p,i_roi_cont_j.raw1);
          i_roi_cont_j.t2 = polyval(p,i_roi_cont_j.raw2);
          if ismember('warpfactor',i_roi_cont_j.Properties.VariableNames)
            i_roi_cont_j.warpfactor = 1 ./ (i_roi_cont_j.Fs .* p(1));
          end
        else  
          err_roi = i_roi_cont_j(off_idx,:);
          error('can''t consolidate within tolerance. Max delta t %f > %f.\nOffending row is t=[%f,%f] of file %s',...
            max_delta_t,timetol,err_roi.starts(1),err_roi.ends(1),err_roi.name{1})
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

