function warpedcoords = bml_timewarp(cfg, master, slave)

  % BML_TIMEWARP aligns and linearly warps slave to master 
  %
  % Use as
  %   slave_t1 = bml_timealign(cfg, master, slave)
  %   
  % This function first aligns slave to master by calling BML_TIMEALIGN and
  % then applies a constrained linear time-warp to slave, in order to
  % maximize the correlation with master. The time-warping is done with the
  % raws pre-processed by BML_TIMEALIGN.
  %
  % The time-warping is done by optimizing the cost function below using
  % the 'simplex' method
  %
  % w(t) = wt0 + pivot_time + (t - pivot_time) ws1
  % s = f(w(t))
  % cost = -s?p/?(s?s p?p) + (wt0/penalty_wt0)^2 + ((ws1-1)/penalty_ws1)^4
  %
  % where pivot_time is the midpoint of the intersection of master and
  % slave after initial alignment, and f(t) is a interpolation function
  % constructed from the slave's data and time points (after alingment).
  % wt0 and ws1 are the time shifting and stretching paramenters,
  % respectiveley. penalty_wt0 and penalty_ws1 are used to constrain their
  % value by adding a penalty cost. 
  % 
  % Parameters
  % ----------
  % cfg is a configuration structure
  % see BML_TIMEALIGN parameters
  % cfg.penalty_wt0 - double: see details above. Defaults to 60. 
  % cfg.penalty_ws1 - double: see details above. Defaults to 1e-3. 
  %
  % master - FT_DATATYPE_RAW continuous with single channel and trial
  % slave - FT_DATATYPE_RAW continuous with single channel and trial
  %
  % Returns
  % -------
  % warpedcoords structure with fields
  % warpedcoords.s1 - integer: first coordinate sample
  % warpedcoords.t1 - double: first coordinate time in seconds
  % warpedcoords.s2 - integer: second coordinate sample
  % warpedcoords.t2 - double: second coordinate time in seconds
  % warpedcoords.wt0
  % warpedcoords.ws1 
  
  penalty_wt0       = bml_getopt(cfg,'penalty_wt0', 60);
  penalty_ws1       = bml_getopt(cfg,'penalty_ws1', 1e-3); 

  mc=[]; sc=[]; %original master and slave time coordinates
  mc.s1=1; mc.s2=length(master.time{1});
  mc.t1=master.time{1}(1); mc.t2=master.time{1}(end);
  sc.s1=1; sc.s2=length(slave.time{1});
  sc.t1=slave.time{1}(1); sc.t2=slave.time{1}(end);  
  
  %aligning and transforming raws
  [slave_delta_t, ~, master, slave] = bml_timealign(cfg, master, slave);
  sc.t1 = sc.t1 + slave_delta_t; sc.t2 = sc.t2 + slave_delta_t;
  
  %calculating pivot time  
  ovlp = [max(mc.t1,sc.t1),min(sc.t2,sc.t2)];
  pivot_time = mean(ovlp);

  %saving cropped start and end indices of original slave raw
  crop_sc=[]; %cropped slave coordinates
  [crop_sc.s1, crop_sc.s2]=bml_crop_idx(sc,ovlp(1),ovlp(2));
  crop_sc.t1=bml_idx2time(sc,crop_sc.s1);
  crop_sc.t2=bml_idx2time(sc,crop_sc.s2);
  
  %cropping raws to overlap region
  master = bml_crop(master, ovlp(1), ovlp(2));
  slave = bml_crop(slave, ovlp(1), ovlp(2));
  
  %linear warping - wt0, ws1
  f = @(t) interp1(slave.time{1}(1,:),slave.trial{1}(1,:),t,'PCHIP',0);
  p = master.trial{1}(1,:);
  t = master.time{1}(1,:);
  s0 = f(t);
  dot0 = sqrt(dot(s0,s0) * dot(p,p)); 
  
  function cost = costfun(param) % [wt0, ws1]
    s = f(param(1) + pivot_time + (t - pivot_time) .* param(2));
    cost = -dot(s,p)/dot0 + (param(1)/penalty_wt0)^2 + ((param(2)-1)/penalty_ws1)^4;
  end

  wt0=0; ws1=1;
  fited=fminsearch(@costfun,[wt0,ws1]);
  wt0=fited(1); ws1=fited(2);

  warpedcoords=[];
  warpedcoords.t1 = pivot_time - wt0 - (1/ws1)*(crop_sc.t2 - crop_sc.t1)/2;
  warpedcoords.t2 = pivot_time - wt0 + (1/ws1)*(crop_sc.t2 - crop_sc.t1)/2;
  warpedcoords.s1 = crop_sc.s1;
  warpedcoords.s2 = crop_sc.s2;
  warpedcoords.wt0 = wt0;
  warpedcoords.ws1 = ws1;

end
