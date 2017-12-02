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
%   cfg.min_events - integer. Minimum number of events required to attemp
%             alingment, defaults to 10. 

scan_step         = bml_getopt(cfg,'scan_step',0.1);
scan              = bml_getopt(cfg,'scan',100);
timewarp          = bml_getopt(cfg,'timewarp',false);
master_events     = bml_getopt(cfg,'master_events');
roi               = bml_getopt(cfg,'roi');
diagnostic_plot   = bml_getopt(cfg,'diagnostic_plot',false);
timetol           = bml_getopt(cfg,'timetol',1e-6);
min_events        = bml_getopt(cfg,'min_events',10);

assert(~isempty(roi),'roi required');
assert(~isempty(master_events),'master_events required');

all_slave_dt = zeros(height(roi),1);
all_warpfactor = ones(height(roi),1);
for i=1:height(roi)
  
  %getting events

	i_slave_events = bml_read_event(roi(i,:));
  if isempty(i_slave_events) || length(i_slave_events) < min_events
    all_slave_dt(i) = nan;
    all_warpfactor(i) = nan;
  else
    cfg=[]; cfg.Fs = 1; %already in seconds
    cfg.starts = roi.starts(i);
    i_slave_events = bml_event2annot(cfg,i_slave_events);
    i_slave_events = bml_annot_table(i_slave_events);

    %doing time alingment
    cfg=[]; 
    cfg.scan=scan; 
    cfg.scan_step=scan_step; 
    cfg.timewarp = timewarp; 
    [slave_dt, min_cost, warpfactor]=bml_timealign_annot(cfg,master_events,i_slave_events);
    all_slave_dt(i) = slave_dt;
    all_warpfactor(i) = warpfactor;

    if istrue(diagnostic_plot)
      tbar = mean(i_slave_events.starts);
      i_slave_events_starts = (i_slave_events.starts - tbar) .* warpfactor + tbar + slave_dt;
      figure;
      plot(master_events.starts,ones(1,height(master_events)),'bo');
      hold on;
      plot(i_slave_events_starts,ones(1,length(i_slave_events_starts)),'r*');
    end

    alignment_error = min_cost/height(i_slave_events);
    assert(alignment_error < timetol,...
      'could not time align within timetol. Mean error %f > %f',alignment_error,timetol);
  end
end

if ~istrue(timewarp)
  all_slave_dt = repmat(nanmean(all_slave_dt),length(all_slave_dt),1);
end

if any(ismissing(all_slave_dt))
  all_slave_dt(ismissing(all_slave_dt)) = nanmean(all_slave_dt);
end
if any(ismissing(all_warpfactor))
  all_warpfactor(ismissing(all_warpfactor)) = nanmean(all_warpfactor);
end


% %calculating linear fit to delays, to apply sort of time warping
% p = polyfit(roi.starts,roi.slave_dt,1);
% roi.starts = roi.starts + polyval(p,roi.starts);
% roi.ends   = roi.ends   + polyval(p,roi.ends);
% roi.t1     = roi.t1     + polyval(p,roi.t1);
% roi.t2     = roi.t2     + polyval(p,roi.t2);
% roi.warpfactor = ones(height(roi),1) * (1+p(1));

midpoint_a = (roi.ends + roi.ends) ./ 2;
midpoint_t = (roi.t1 + roi.t2) ./ 2;
roi.starts = (roi.starts - midpoint_a) .* all_warpfactor + midpoint_a + all_slave_dt;
roi.ends = (roi.ends - midpoint_a) .* all_warpfactor + midpoint_a + all_slave_dt;
roi.t1 = (roi.t1 - midpoint_t) .* all_warpfactor + midpoint_t + all_slave_dt;
roi.t2 = (roi.t2 - midpoint_t) .* all_warpfactor + midpoint_t + all_slave_dt;

roi.warpfactor = all_warpfactor;
roi.chunk_id = (1:height(roi))';
roi.sync_channel = repmat({'digital'},height(roi),1);
roi.sync_type = repmat({'slave'},height(roi),1);

sync_roi = bml_roi_table(roi);
