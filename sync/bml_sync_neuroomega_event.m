function sync_roi = bml_sync_neuroomega_event(cfg)

% BML_SYNC_NEUROOMEGA_EVENT synchronizes neuroomega files based on events
%
% Use as 
%    sync_roi = bml_sync_neuroomega_event(cfg)
%
%   cfg.master_events - events to align to in annot table in master time
%   cfg.roi - roi table for neuroomega files to be synchronized
%   cfg.timewarp - logical: Should slave time be warped? defaults to 
%            true.
%   cfg.scan - double: number of seconds to scan for optimal alignment 
%             (defaults to 100)
%   cfg.scan_step - double: step size of initial scan for alignment
%             (defaults to 0.1)
%   cfg.diagnostic_plot - logical
%   cfg.timetol - numeric, time tolerance in seconds. Defaults to 1e-6
%   cfg.coarsetol - numeric, time tolerance in seconds for coarse
%             alignment. Defaults to 100s
%   cfg.min_events - integer. Minimum number of events required to attemp
%             alingment, defaults to 10. 
%   cfg.strict - logical. Issue errors if timetol is violated instead of errors. 
%             Defaults to false. 
%
%   Additional arguments passed to bml_timelaign_annot
%   --------------------------------------------------
%   cfg.cliptime - double: time mismatch at which cost gets clipped. Defaults 1s
%   cfg.censor_mismatch - double: time mismatch at which point gets censored
%   cfg.restrict_master_by - str: column name from master used to group
%     events. Synchroniztion is restricted to these groups. If slave events
%     span more than one group, the least represented group events from
%     master are censored for the alignment. Useful when one wav file
%     spans more than one trellis file. 
%
% returns a roi table

scan_step         = bml_getopt(cfg,'scan_step',0.1);
scan              = bml_getopt(cfg,'scan',100);
timewarp          = bml_getopt(cfg,'timewarp',false);
master_events     = bml_getopt(cfg,'master_events');
roi               = bml_getopt(cfg,'roi');
diagnostic_plot   = bml_getopt(cfg,'diagnostic_plot',false);
timetol           = bml_getopt(cfg,'timetol',1e-6);
min_events        = bml_getopt(cfg,'min_events',10);
strict            = bml_getopt(cfg,'strict',false);
coarsetol         = bml_getopt(cfg,'coarsetol',100);

assert(~isempty(roi),'roi required');
assert(~isempty(master_events),'master_events required');

all_slave_dt = zeros(height(roi),1);
all_warpfactor = ones(height(roi),1);
all_meanerror = zeros(height(roi),1);
for i=1:height(roi)
  
  %getting events
  i_slave_events = bml_read_event(roi(i,:));
  if isempty(i_slave_events) || length(i_slave_events) < min_events
    all_slave_dt(i) = nan;
    all_warpfactor(i) = nan;
  else
    cfg1=[]; cfg1.Fs = 1; %already in seconds
    cfg1.starts = roi.starts(i);
    i_slave_events = bml_event2annot(cfg1,i_slave_events);
    i_slave_events = bml_annot_table(i_slave_events);
    
    %selecting subset of master events in the vecinity of roi events
    i_master_events = bml_annot_filter(master_events, bml_annot_extend(roi(i,:),coarsetol));
    
    %doing time alingment
    %cfg=[]; 
    cfg.scan=scan; 
    cfg.scan_step=scan_step; 
    cfg.timewarp = timewarp; 
    [slave_dt, min_cost, warpfactor]=bml_timealign_annot(cfg,master_events,i_slave_events);
    all_slave_dt(i) = slave_dt;
    all_warpfactor(i) = warpfactor;

    if diagnostic_plot
      tbar = mean(i_slave_events.starts);
      i_slave_events_starts = (i_slave_events.starts - tbar) .* warpfactor + tbar + slave_dt;
      figure;
      plot(i_master_events.starts,ones(1,height(i_master_events)),'bo');
      hold on;
      plot(i_slave_events_starts,ones(1,length(i_slave_events_starts)),'r*');
    end

    all_meanerror(i) = min_cost/height(i_slave_events);
    if all_meanerror(i) > timetol
      if strict
        error('could not time align within timetol. Mean error %f > %f. File %s',all_meanerror(i),timetol,roi.name{i});
      else
        warning('could not time align within timetol. Mean error %f > %f. File %s. Ignoring this file during consolidation.',all_meanerror(i),timetol,roi.name{i});
        all_slave_dt(i) = nan;
        all_warpfactor(i) = nan;
      end
    end
  end
end

if ~timewarp
  all_slave_dt = repmat(nanmean(all_slave_dt),length(all_slave_dt),1);
end

%consolidating results
roi.slave_dt = all_slave_dt;
roi.warpfactor = all_warpfactor;
roi.alignment_error = all_meanerror;

cfg1=[];
cfg1.criterion = @(x) (abs((max(x.ends)-min(x.starts))-sum(x.duration))<10e-3);
cont_roi = bml_annot_consolidate(cfg1,roi);

consolidated_roi = table();
for i=1:height(cont_roi)
  i_roi = roi(roi.id >= cont_roi.id_starts(i) & roi.id <= cont_roi.id_ends(i),:);
  i_roi.slave_dt(:) = nanmean(i_roi.slave_dt);
  i_roi.warpfactor(:) = nanmean(i_roi.warpfactor);
  consolidated_roi = [consolidated_roi; i_roi];
end
roi = consolidated_roi;

if any(ismissing(roi.slave_dt))
  warning('Using mean dt for some files');
  roi.slave_dt(ismissing(roi.slave_dt)) = nanmean(roi.slave_dt);
end
if any(ismissing(roi.warpfactor))
  warning('Using mean warpfactor for some files');
  roi.warpfactor(ismissing(roi.warpfactor)) = nanmean(roi.warpfactor);
end

midpoint_a = (roi.starts + roi.ends) ./ 2;
midpoint_t = (roi.t1 + roi.t2) ./ 2;
roi.starts = (roi.starts - midpoint_a) .* roi.warpfactor + midpoint_a + roi.slave_dt;
roi.ends = (roi.ends - midpoint_a) .* roi.warpfactor + midpoint_a + roi.slave_dt;
roi.t1 = (roi.t1 - midpoint_t) .* roi.warpfactor + midpoint_t + roi.slave_dt;
roi.t2 = (roi.t2 - midpoint_t) .* roi.warpfactor + midpoint_t + roi.slave_dt;

roi.chunk_id = (1:height(roi))';
roi.sync_channel = repmat({'digital'},height(roi),1);
roi.sync_type = repmat({'slave'},height(roi),1);

sync_roi = bml_roi_table(roi);

sync_roi(:,{'id','starts','ends','duration','name','warpfactor'})

