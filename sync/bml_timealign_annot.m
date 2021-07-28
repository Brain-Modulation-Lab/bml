function [slave_delta_t, min_cost, warpfactor] = bml_timealign_annot(cfg, master, slave)

  % BML_TIMEALIGN_ANNOT aligns slave to master and returns the slave's delta t
  %
  % Use as
  %   slave_delta_t = bml_timealign(cfg, master, slave)
  %   [slave_delta_t, min_cost] = bml_timealign(cfg, master, slave)
  %   [slave_delta_t, min_cost, warpfactor] = bml_timealign(cfg, master, slave)
  %
  % cfg is a configuration structure with fields:
  % cfg.scan - double: time window in which to scan for a maximal correlation
  %            if a scalar is given the time window is [-scan, scan]
  %            if a length 2 vector is given it should be [-a, b], where 'a'
  %            and 'b' are positive numbers in seconds. 
  % cfg.scan_step - double: time step for initial scan in seconds
  % cfg.censor_mismatch - double: time mismatch at which point gets censored
  % cfg.cliptime - double: time mismatch at which cost gets clipped. Defaults 1s
  % cfg.timewarp - logical: should time warping be allowed. Defaults to false
  % cfg.restrict_master_by - str: column name from master used to group
  %     events. Synchroniztion is restricted to these groups. If slave events
  %     span more than one group, the least represented group events from
  %     master are censored for the alignment. Useful when one wav file
  %     spans more than one trellis file. 
  %
  % master - annot table 
  % slave - annot table
  %
  % returns
  % slave_delta_t - double: time in seconds by which to shift the slave to 
  %           align it to master
  % min_cost - double: minimal (optimized) value of the cost function. 

  scan      = bml_getopt(cfg, 'scan', 100);
  scan_step = bml_getopt(cfg, 'scan_step', 0.1);
  censor_mismatch = bml_getopt(cfg, 'censor_mismatch', scan_step);
  timewarp  = bml_getopt(cfg, 'timewarp', false);
  cliptime  = bml_getopt(cfg, 'cliptime', 1);
  restrict_master_by = bml_getopt(cfg,'restrict_master_by',[]);
  master    = bml_annot_table(master);
  slave     = bml_annot_table(slave);
  slave_starts_mean = mean(slave.starts);
  slave_starts_minus_mean = slave.starts-slave_starts_mean;
  
  %cost function with timewarp
  %cost=costfun([slave_delta_t, warpfactor])
  function cost=costfun(x0)
    y=master.starts;
    x=slave_starts_minus_mean .* x0(2) + slave_starts_mean + x0(1);
    cost=0;
    for i=1:length(x)
     %cost = cost + min(abs(x(i)-y))^2;
     cost = cost + min(min(abs(x(i)-y)),cliptime)^2;
    end
    cost = sqrt(cost);
  end

  %cost function without timewarp (timewarp = 1)
  %cost=costfun(slave_delta_t)
  function cost=costfun1(x0)
    y=master.starts;
    x=slave.starts + x0(1);
    cost=0;
    for i=1:length(x)
     %cost = cost + min(abs(x(i)-y))^2;
     cost = cost + min(min(abs(x(i)-y)),cliptime)^2;
    end
    cost = sqrt(cost);
  end

  %restrict by option
  if ~isempty(restrict_master_by)
    if(ismember(restrict_master_by,master.Properties.VariableNames))
      master.restrict_by = master{:,restrict_master_by};  
    else
      warning('restrict_master_by value doesn''t match any column of master');
      master.restrict_by(:)=1;
    end
  else
    master.restrict_by(:)=1;
  end

  %initial brute force scan
  initial_scan = linspace(-scan,scan,floor(2*scan/scan_step)+1);
  warpfactor = 1;
  slave_delta_t=0;
  min_cost=costfun1(slave_delta_t);
  for j=1:length(initial_scan)
    i_cost = costfun1(initial_scan(j));
    if i_cost < min_cost
      min_cost = i_cost;
      slave_delta_t=initial_scan(j);
    end
  end

  %censoring unpaired slave events
  slave_master_dt = zeros(height(slave),1);
  slave_master_restrict_by = nan(height(slave),1);
  for i_slave=1:height(slave)
    [slave_master_dt(i_slave),idx_min] = min(abs(slave.starts(i_slave) + slave_delta_t - master.starts));
    slave_master_restrict_by(i_slave) = master.restrict_by(idx_min);
  end
  censored_slave = (slave_master_dt > censor_mismatch) | (slave_master_restrict_by~=mode(slave_master_restrict_by));
  if sum(censored_slave)>0
    warning("%i slave events censored in synchronization",sum(censored_slave));
    slave = slave(~censored_slave,:);
    slave_starts_mean = mean(slave.starts);
    slave_starts_minus_mean = slave.starts-slave_starts_mean;
  end
  
  %optimizing
  if timewarp
    fitted=fminsearch(@costfun,[slave_delta_t, warpfactor]);
    slave_delta_t=fitted(1);
    warpfactor = fitted(2);
  else
    fitted=fminsearch(@costfun1,slave_delta_t);
    slave_delta_t=fitted(1);
  end
  min_cost = costfun([slave_delta_t,warpfactor]);
  
end
  

    
    
    