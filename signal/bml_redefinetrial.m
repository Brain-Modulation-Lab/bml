function redefined = bml_redefinetrial(cfg, raw)

% BML_REDEFINETRIAL creates new epoching from a raw object
%
% raw - FT_DATAYPR_RAW to be re-epoched with time in global coordinates
% cfg - configuraton structure
%
% cfg.epoch - ANNOT table with new epoching
% cfg.t0 - reference time for each epoch. If not given the time is kept in
%          global time coordinates. Can be string or char is given that matches a 
%          variable of cfg.epoch or a numeric vector of the same length than cfg.epoch
% cfg.regularize - if true, resulting times are forced to be equal. 
% cfg.warn - logical indicating if warnings should be issued. Defaults to true
%
% returns a raw with new trials. The epoch ANNOT is added as a new field in the 
% raw, changing the id to match the index of the corresponding trials if necessary.

epoch      = bml_annot_table(bml_getopt(cfg,'epoch'),'epoch');
t0         = bml_getopt(cfg,'t0');
regularize = bml_getopt(cfg,'regularize',false);
warn       = bml_getopt(cfg,'warn',true);


if istrue(regularize)
  keyboard %have to implement this
end

if ~isempty(t0)
  if isstring(t0) || ischar(t0)
    t0 = cellstr(t0);
  end
    
  if iscellstr(t0)
    assert(numel(t0)==1,"single t0 variable required");
    if ismember(t0,epoch.Properties.VariableNames)
      t0 = epoch.(t0{1});
    else
      error("t0 doesn't match any variable in epoch");
    end
  end
  
  if isnumeric(t0)
    assert(length(t0)==height(epoch),"incorrect length for t0");
  else
    error("t0 should be a numeric vector, or be the name of a numeric variable in epoch");
  end
end

%creating output raw
redefined = [];
redefined.trial = {};
redefined.time = {};
redefined.epoch = table();
redefined.label = raw.label;
if ismember('hdr',fields(raw))
  redefined.hdr = raw.hdr;
end

%extracting trial info from raw
raw_trial = bml_annot_table(bml_raw2annot(raw),'raw');

%looping though epochs
for i=1:height(epoch)
  
  %intersecting epochs with raw's trials
  new_row = epoch(i,:);
  i_raw_trial = bml_annot_intersect(struct('keep','x'),raw_trial,epoch(i,:));
  
  %if no intersection, move to next epoch
  if isempty(i_raw_trial)
    if istrue(warn)
      warning("epoch %i not found in raw",i);
    end
    continue
  end
  
  %ensure only one intersection
  if height(i_raw_trial)>1
    [~,max_i]=max(i_raw_trial.duration);
    if warn
      warning("several trials of raw match to epoch %i. Selecting trial %i",i,i_raw_trial.id(max_i));
    end
    i_raw_trial = i_raw_trial(max_i,:);
  end
  
  %partial epoch
  if (epoch.duration(i) > i_raw_trial.duration) && istrue(warn)
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
  redefined.trial{new_row.id} = raw.trial{i}(:,s:e);
  redefined.time{new_row.id} = raw.time{i}(:,s:e);
  redefined.epoch = [redefined.epoch; new_row];
  %cropped.sampleinfo(i,:) = [s,e];
  
  %changing time reference if t0 is present
  if ~isempty(t0)
    redefined.time{new_row.id} = redefined.time{new_row.id} - t0(i);
  end
 
end

redefined.epoch = bml_annot_table(redefined.epoch,'epoch');




