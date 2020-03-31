function [redefined, redefined_epoch] = bml_redefinetrial(cfg, raw)

% BML_REDEFINETRIAL creates new epoching from a raw object (not necessarily continuous)
%
% Use as
%   redefined = bml_redefinetrial(cfg, raw)
%
% raw - FT_DATAYPE_RAW to be re-epoched with time in global coordinates
% cfg - configuraton structure
% cfg.epoch - ANNOT table with new epoching
% cfg.timelock - reference time for timelocking each epoch. If not specified the time is kept in
%          global time coordinates. Can be string or char that matches a 
%          variable of cfg.epoch, or a numeric vector of the same length than cfg.epoch
% cfg.timesnap - bool, if true times are snapped to 'round' value according
%          to sampling rate. Defaults to true if timelock is given, false
%          if not.
% cfg.timesignif - number of significant digits to consider for smapling rate
%          during time snapping. Defaults to 4. 
% cfg.t0 - same as timelock. Deprecated. 
% cfg.regularize - if true, resulting times are forced to be equal.
%          Defaults to false. [NOT IMPLEMENTED]
% cfg.warn - logical indicating if warnings should be issued. Defaults to true
%
% returns a raw with new trials. The epoch ANNOT is added as a new field in the 
% raw, changing the id to match the index of the corresponding trials if necessary.

epoch      = bml_annot_table(bml_getopt(cfg,'epoch'),'epoch');
t0         = bml_getopt(cfg,'t0');
timelock   = bml_getopt(cfg,'timelock');
regularize = bml_getopt(cfg,'regularize',false);
warn       = bml_getopt(cfg,'warn',true);

if isempty(timelock) && ~isempty(t0)
  warning('t0 option deprecated. Use timelock instead');
  timelock = t0;
end

timesnap   = bml_getopt(cfg,'timesnap',~isempty(timelock));
timesignif = bml_getopt(cfg,'timesignif',4);

if regularize
  error('regularize not implemented')
end

if ~isempty(timelock)
  if isstring(timelock) || ischar(timelock)
    timelock = cellstr(timelock);
  end
    
  if iscellstr(timelock)
    assert(numel(timelock)==1,"single t0 variable required");
    if ismember(timelock,epoch.Properties.VariableNames)
      timelock = epoch.(timelock{1});
    else
      error("t0 doesn't match any variable in epoch");
    end
  end
  
  if isnumeric(timelock)
    assert(length(timelock)==height(epoch),"incorrect length for timelock");
  else
    error("timelock should be a numeric vector, or be the name of a numeric variable in epoch");
  end
end

%creating output raw
redefined = [];
redefined.trial = {};
redefined.time = {};
redefined_epoch = table();
redefined.label = raw.label;
if ismember('hdr',fields(raw))
  redefined.hdr = raw.hdr;
end

%extracting trial info from raw
raw_trial = bml_annot_table(bml_raw2annot(raw),'raw');
raw_trial.midpoint = (raw_trial.starts + raw_trial.ends)/2;

if timesnap
  raw_trial.Fs = round(raw_trial.Fs,timesignif,'significant');
end
if regularize && length(uniquetol(raw_trial.Fs))>1
  error('different sampling rates for different trials of raw. Can''t regularize');
end

%looping though epochs
for i=1:height(epoch)
  
  %intersecting epochs with raw's trials
  new_row = epoch(i,:);
  i_raw_trial = bml_annot_intersect(struct('keep','x'),raw_trial,new_row);

  %if no intersection, move to next epoch
  if isempty(i_raw_trial)
    if warn
      warning("epoch %i not found in raw",i);
    end
    continue
  end
  
  %selecting best intersection (largest duration and centered)
  if height(i_raw_trial)>1
    max_duration=max(i_raw_trial.duration);
    i_raw_trial = i_raw_trial(i_raw_trial.duration == max_duration,:);
    [~,min_i]=min(abs((i_raw_trial.starts+i_raw_trial.ends)/2 - i_raw_trial.midpoint));
    i_raw_trial = i_raw_trial(min_i,:);  
  end

  %partial epoch
  timetol = epoch.duration(i)*(10^(-timesignif));
  if (abs(epoch.duration(i) - i_raw_trial.duration) > timetol) && warn
    warning('partial epoch %i loaded',i);
  end
  
  new_row.starts = i_raw_trial.starts;
  new_row.ends = i_raw_trial.ends;
  
  %cropping
  [s,e]=bml_crop_idx(i_raw_trial,i_raw_trial.starts,i_raw_trial.ends);

	if s < 1; s=1; end
	if e > i_raw_trial.nSamples; e = i_raw_trial.nSamples; end

  %creating trial
  new_row.id = numel(redefined.trial) + 1;
  redefined.trial{new_row.id} = raw.trial{i_raw_trial.raw_id}(:,s:e);
  new_time =  raw.time{i_raw_trial.raw_id}(:,s:e);
  %changing time reference if t0 is present
  if ~isempty(timelock)
    new_time = new_time - timelock(i);
  end
  if timesnap
    sT = round(1/i_raw_trial.Fs(1),timesignif,'significant');
    len_t = length(new_time);
    mid_idx = ceil(len_t/2);
    mid_time = sT*round(new_time(mid_idx)/sT,0);
    new_time = (((-mid_idx+1):(len_t-mid_idx)) .* sT) + mid_time;
  end
  redefined.time{new_row.id} = new_time;
  redefined_epoch = [redefined_epoch; new_row];
  %cropped.sampleinfo(i,:) = [s,e];

end

redefined = ft_datatype_raw(redefined);

