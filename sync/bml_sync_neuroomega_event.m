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

scan_step         = bml_getopt(cfg,'scan_step',0.1);
scan              = bml_getopt(cfg,'scan',100);
timewarp          = bml_getopt(cfg,'timewarp',false);
master_events     = bml_getopt(cfg,'master_events');
roi               = bml_getopt(cfg,'roi');
diagnostic_plot   = bml_getopt(cfg,'diagnostic_plot',false);

assert(~isempty(roi),'roi required');
assert(~isempty(master_events),'master_events required');

all_slave_dt = zeros(height(roi),1);
for i=1:height(roi)
  
  %getting events
  i_slave_events = bml_read_event(roi(i,:));
  cfg=[]; cfg.Fs = 1; %already in seconds
  cfg.starts = roi.starts(i);
  i_slave_events = bml_event2annot(cfg,i_slave_events);
  i_slave_events = bml_annot_table(i_slave_events);
  
  %doing time alingment
  cfg=[]; cfg.scan=50; cfg.scan_step=.1; 
  slave_dt=bml_timealign_annot(cfg,master_events,i_slave_events);
  all_slave_dt(i) = slave_dt;
  
  if istrue(diagnostic_plot)
    i_slave_events = bml_annot_t0(-slave_dt,i_slave_events);
    figure;
    plot(master_events.starts,ones(1,height(master_events)),'bo');
    hold on;
    plot(i_slave_events.starts,ones(1,height(i_slave_events)),'r*');
  end

end

if ~istrue(timewarp)
  all_slave_dt = repmat(mean(all_slave_dt),length(all_slave_dt),1);
end
roi.slave_dt = all_slave_dt;

%calculating linear fit to delays, to apply sort of time warping
p = polyfit(roi.starts,roi.slave_dt,1);

roi.starts = roi.starts + polyval(p,roi.starts);
roi.ends   = roi.ends   + polyval(p,roi.ends);
roi.t1     = roi.t1     + polyval(p,roi.t1);
roi.t2     = roi.t2     + polyval(p,roi.t2);

roi.chunk_id = (1:height(roi))';
roi.warpfactor = ones(height(roi),1) * (1+p(1));
roi.sync_channel = repmat({'digital'},height(roi),1);
roi.sync_type = repmat({'slave'},height(roi),1);

sync_roi = bml_roi_table(roi);
