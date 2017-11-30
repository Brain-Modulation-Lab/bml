function [slave_delta_t, min_cost] = bml_timealign_annot(cfg, master, slave)

  % BML_TIMEALIGN_ANNOT aligns slave to master and returns the slave's delta t
  %
  % Use as
  %   slave_delta_t = bml_timealign(cfg, master, slave)
  %   [slave_delta_t, max_corr] = bml_timealign(cfg, master, slave)
  %
  % cfg is a configuration structure with fields:
  % cfg.scan - double: time window in which to scan for a maximal correlation
  %            if a scalar is given the time window is [-scan, scan]
  %            if a length 2 vector is given it should be [-a, b], where 'a'
  %            and 'b' are positive numbers in seconds. 
  % cfg.scan_step - double: time step for initial scan in seconds
  %
  % master - annot table 
  % slave - annot table
  %
  % returns
  % slave_delta_t - double: time in seconds by which to shift the slave to 
  %           align it to master
  % max_corr - double:

  scan      = bml_getopt(cfg, 'scan', 100);
  scan_step = bml_getopt(cfg, 'scan_step', 0.1);
 
  master = bml_annot_table(master);
  slave  = bml_annot_table(slave);
  
  function cost=costfun(slave_delta_t)
    y=master.starts;
    x=slave.starts + slave_delta_t;
    cost=0;
    for i=1:length(x)
     cost = cost + min(abs(x(i)-y))^2;
    end
    cost = sqrt(cost);
  end

  initial_scan = linspace(-scan,scan,floor(2*scan/scan_step)+1);
  slave_delta_t=0;
  min_cost=costfun(slave_delta_t);
  for j=1:length(initial_scan)
    i_cost = costfun(initial_scan(j));
    if i_cost < min_cost
      min_cost = i_cost;
      slave_delta_t=initial_scan(j);
    end
  end

  fited=fminsearch(@costfun,slave_delta_t);
  slave_delta_t=fited(1);
  min_cost = costfun(slave_delta_t);
  
end
  

    
    
    