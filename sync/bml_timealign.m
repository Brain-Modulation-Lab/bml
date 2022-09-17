function [slave_delta_t, max_corr, master, slave] = bml_timealign(cfg, master, slave)

  % BML_TIMEALIGN aligns slave to master and returns the slave's delta t
  %
  % Use as
  %   slave_delta_t = bml_timealign(master, slave)
  %   slave_delta_t = bml_timealign(cfg, master, slave)
  %   [slave_delta_t, max_corr] = bml_timealign(cfg, master, slave)
  %   [slave_delta_t, max_corr, master, slave] = bml_timealign(cfg, master, slave)
  %
  %
  % cfg is a configuration structure with fields:
  % cfg.resample_freq - double: frequency to resample and aligned master and
  %            slave (Hz). Defaults to 10000.
  % cfg.method - string: method use for preprocessing master and slave
  %            'env' or 'envelope' (default) - see BML_ENVELOPE_BINABS
  %            'lpf' or 'low-pass-filter' - see ft_preproc_lowpassfilter
  % cfg.env_freq - double: frequency of the envelope. Defaults to 100Hz
  % cfg.lpf_freq - double: cut-frequency of the low-pass filter. Defaults to
  %            4000Hz. 
  % cfg.scan - double: time window in which to scan for a maximal correlation
  %            if a scalar is given the time window is [-scan, scan]
  %            if a length 2 vector is given it should be [-a, b], where 'a'
  %            and 'b' are positive numbers in seconds. 
  % cfg.freqreltol - double: frequency relative tolerance. defaults to 1e-5
  % cfg.penalty_tau - double: penalty time use to weight the correlation.
  %            This allows to bound slave_delta_t (as with cfg.scan) but in
  %            a continuous way. If empty (default) no penalty is applied.
  % cfg.penalty_n - double: penalty 'hill-coefficient' use to weight the
  %            correlation. Defines how abrupt is the penalty increase when
  %            slave_delta_t > cfg.penalty_tau. Defaults to 2. 
  % cfg.ft_feedback - string: default to 'no'. Defines verbosity of fieldtrip
  %            functions 
  % cfg.simulate_aliasing - bool, indicates if alising should be simulated
  %             on the slave when downsampling. Useful if one if the signals was not
  %             low-pass filtered at aquisition time (e.g. natus DC
  %             channels). Defaults to true. 
  %
  % master - FT_DATATYPE_RAW continuous with single channel and trial
  % slave - FT_DATATYPE_RAW continuous with single channel and trial
  %
  % returns
  % slave_delta_t - double: time in seconds by which to shift the slave to 
  %           align it to master
  % max_corr - double: maximum correlation coefficient achieved for the shift
  %           slave_delta_t
  % master - FT_DATATYPE_RAW: master raw after applying the preprocessing
  % slave - FT_DATATYPE_RAW: slave raw after applying the preprocessing
  
  if nargin == 2
    slave = master;
    master = cfg;
    cfg = [];
  elseif nargin ~= 3
    error('incorrect number of arguments in call');
  end
  
  resample_freq     = bml_getopt(cfg,'resample_freq', 10000);
  scan              = bml_getopt(cfg, 'scan');
  freqreltol        = bml_getopt(cfg, 'freqreltol', 1e-5);
  method            = string(bml_getopt(cfg, 'method', 'envelope'));
  env_freq          = bml_getopt(cfg,'env_freq', 100);
  lpf_freq          = bml_getopt(cfg,'lpf_freq', 4000);
  penalty_tau       = bml_getopt(cfg,'penalty_tau');
  penalty_n         = bml_getopt(cfg,'penalty_n', 2); 
  simulate_aliasing = bml_getopt(cfg,'simulate_aliasing', 1); 
  ft_feedback       = bml_getopt(cfg,'ft_feedback','no');
  ft_feedback       = ft_feedback{1};

  %assert single trial and channel
  if numel(master.trial) > 1; error('master should be single trial raw'); end
  if numel(slave.trial) > 1; error('slave should be single trial raw'); end
  if numel(master.label) > 1; error('master should be single channel raw'); end
  if numel(slave.label) > 1; error('slave should be single channel raw'); end

  %calculating scan range
  mc=[]; sc=[]; %master and slave time coordinates
  mc.s1=1; mc.s2=length(master.time{1});
  mc.t1=master.time{1}(1); mc.t2=master.time{1}(end);
  sc.s1=1; sc.s2=length(slave.time{1});
  sc.t1=slave.time{1}(1); sc.t2=slave.time{1}(end);
  max_scan_range = [mc.t1 - sc.t2, mc.t2 - sc.t1];
  if prod(max_scan_range) > 0 % if files do not overlap
    slave_delta_t=nan;
    max_corr=nan;
    warning('files do not overlap');
    return
  end
  if isempty(scan)
    scan = max_scan_range;
  elseif length(scan)==1
    scan=[max(-scan,max_scan_range(1)), min(scan,max_scan_range(2))];
  elseif length(scan)==2
    scan=[max(scan(1),max_scan_range(1)), min(scan(2),max_scan_range(2))];  
  else
    error('invalid use of cfg.scan argument');
  end

  %robust estimation of mean and std
  master_median = median(master.trial{1});
  slave_median = median(slave.trial{1});
  master_std = robust_std(master.trial{1});
  slave_std = robust_std(slave.trial{1});
  if master_std==0; error('master can''t be correlated'); end
  if slave_std==0; error('slave can''t be correlated'); end

  %cropping and padding to correlation time window
  ctw = [sc.t1+scan(1), sc.t2+scan(2)];
  master = bml_pad(master, ctw(1), ctw(2), 0);
  slave = bml_pad(slave, master.time{1}(1), master.time{1}(end), 0);

  %common resample frequency
  cfg=[]; cfg.feedback=ft_feedback;
  cfg.resamplefs=resample_freq;
  cfg.trackcallinfo=false;
  cfg.showcallinfo='no';
  master = ft_resampledata(cfg, master);
  cfg=[]; cfg.feedback=ft_feedback;
  cfg.trackcallinfo=false;
  cfg.showcallinfo='no';
  if simulate_aliasing
	cfg.time=master.time; cfg.method='linear';
    slave = ft_resampledata(cfg, slave);  
  else
    error('Low pass filter to avoid aliasing not implemented'); 
  end

  %checking slave resampling
  if abs(slave.fsample/master.fsample-1) < freqreltol
    slave.fsample = master.fsample;
  else
    error('failed to resample slave to master''s time');
  end
  is_nan=isnan(slave.trial{1});
  if sum(is_nan)>0
    master.trial{1} = master.trial{1}(:,~is_nan);
    master.time{1} = master.time{1}(:,~is_nan);
    slave.trial{1} = slave.trial{1}(:,~is_nan);
    slave.time{1} = slave.time{1}(:,~is_nan);
  end

  %methods 
  if ismember(lower(method),{'env','envelope'})  %envelope correlation
    cfg=[]; cfg.freq = env_freq; %calculating envelops
    master = bml_envelope_binabs(cfg,master);
    slave = bml_envelope_binabs(cfg,slave);
    try_polarity=false;

  elseif ismember(lower(method),{'lpf','low-pass-filter'})  %low-pass-filter
    master.trial{1} = ft_preproc_lowpassfilter(master.trial{1},...
                      master.fsample, lpf_freq, 4, 'but', 'twopass');
    slave.trial{1} = ft_preproc_lowpassfilter(slave.trial{1},...
                      slave.fsample, lpf_freq, 4, 'but', 'twopass');              
    try_polarity=true;                

  else
    error('unknown method');
  end

  %normalizing data
  master.trial{1} = (master.trial{1} - master_median) / master_std;
  slave.trial{1} = (slave.trial{1} - slave_median) / slave_std;

  %correlation
  [corr,lag]=xcorr(master.trial{1}(1,:), slave.trial{1}(1,:),...
                    floor(max(abs(scan))*master.fsample),'coeff');
  [max_corr_idx,max_corr] = find_delta_corr(corr,lag,penalty_tau,penalty_n);  

  if try_polarity                              
    [corr_m,lag_m]=xcorr(master.trial{1}(1,:), (-1).* slave.trial{1}(1,:),...
                      floor(max(abs(scan))*master.fsample),'coeff');                 
    [max_corr_idx_m,max_corr_m] = find_delta_corr(corr_m,lag_m,penalty_tau,penalty_n);   
    if max_corr_m > max_corr
      slave.trial{1}=(-1).* slave.trial{1};
      max_corr_idx = max_corr_idx_m;
      max_corr = max_corr_m;
      lag=lag_m;
    end
  end

  slave_delta_t = lag(max_corr_idx)/master.fsample;
  slave.time{1} = slave.time{1} + slave_delta_t;

end

% private function 
function [max_corr_idx,max_corr] = find_delta_corr(corr,lag,penalty_tau,penalty_n)
  if ~isempty(penalty_tau)
    [~,max_corr_idx]=max(corr./((penalty_tau*master.fsample)^penalty_n + abs(lag).^penalty_n));
    max_corr=corr(max_corr_idx);
  else
    [max_corr,max_corr_idx]=max(corr);
  end

end
