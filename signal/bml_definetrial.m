function trl_raw = bml_definetrial(cfg,raw)

% BML_DEFINETRIAL transforms a continuous raw into a trialed raw 
%
% Use as
%   trl_raw = bml_definetrial(cfg,raw)
%   trl_raw = bml_definetrial(cfg.annot,raw)
%
% raw - continuous raw file, with time consistent with annot stars/ends
%
% cfg.annot - annotation table
% cfg.fixsamples - number of samples for each trial, or 
%       false to allow different length trials, or
%       'auto' to use fixsamples if duration of all annots is the same 
% cfg.trial_t0 - defines the time reference for the trials
%       if false, the same time reference for all files is maintained
%       if true each trial gets its own time reference, at the begging of the trial
%       if char or cellstr or string, it is used to select a variable from 
%         annot to use as time reference for each trial
%       if table or numeric, and length matched trials, these values are
%         used as time reference for each trial
% cfg.equalize_times - logical. if true times all trials get the same time vector
%       defaults to true if duration of all annots is the same and trial_t0
%       is not false
% cfg.timetol - double. time tolerance in seconds. Defaults to 1e-6
%
% returns a FT_DATATYPE_RAW with the trials defined by cfg.annot

if istable(cfg)
  cfg = struct('annot',cfg);
end
annot            = bml_getopt(cfg,'annot');
fixsamples       = bml_getopt(cfg,'fixsamples','auto');
trial_t0         = bml_getopt(cfg,'trial_t0',false);
equalize_times   = bml_getopt(cfg,'equalize_times');
timetol          = bml_getopt(cfg,'timetol',1e-6);

assert(~isempty(annot),'annot required');
assert(~isempty(raw),'raw required');
assert(isstruct(raw),'ivalid raw');
assert(all(ismember({'label','time','trial'},fields(raw))),'ivalid raw');
assert(numel(raw.trial)==1,'raw should have single trial (continuous)');

if islogical(trial_t0)
  if trial_t0
    trial_t0 = annot.starts;
  else
    trial_t0 = zeros(height(annot),1);
  end
elseif ischar(trial_t0) || isstring(trial_t0) || iscellstr(trial_t0)
  trial_t0 = cellstr(trial_t0);
  if ismember(trial_t0,annot.Properties.VariableNames)
    trial_t0 = annot.(trial_t0{1});
  else
    error('specified trial_t0 doesn''t coincide with annot''s variable names');
  end
elseif istable(trial_t0)
  if width(trial_t0)==1 && height(trial_t0)==height(annot)
    trial_t0 = trial_t0{:,1};
  else
    error('invalid trial_t0');
  end
elseif isnumeric(trial_t0)
  if size(trial_t0,1) <  size(trial_t0,2)
    trial_t0 = trial_t0';
  end
  assert(size(trial_t0,1) == height(annot),'invalid trial_t0');    
else
  error('invalid trial_t0');
end
  
coord = bml_raw2coord(raw);
trl = [bml_time2idx(coord,annot.starts), bml_time2idx(coord,annot.ends)];

if isnumeric(fixsamples)
  trl(:,2) = trl(:,1) + fixsamples;
elseif islogical(fixsamples) && ~fixsamples
  %do nothing
elseif strcmp(fixsamples,'auto')
  if length(unique(annot.duration))==1
    trl(:,2) = trl(:,1) + min(trl(:,2)-trl(:,1));
  end
end

trl_raw=raw;
trl_raw.trial = cell(1,size(trl,1));
trl_raw.time = cell(1,size(trl,1));
trl_raw.sampleinfo = trl;
for i=1:size(trl,1)
  trl_raw.trial{i}=raw.trial{1}(:,trl(i,1):trl(i,2));
  trl_raw.time{i}=raw.time{1}(:,trl(i,1):trl(i,2)) - trial_t0(i);
end

if isempty(equalize_times)
  equalize_times = ~all(trial_t0==0) && length(unique(trl(i,2)-trl(i,1)))==1;
end
if istrue(equalize_times)
  trial_len = unique(trl(i,2)-trl(i,1)+1);
  assert(~all(trial_t0==0) && length(trial_len)==1,...
    'can''t equalize times');
  period = cellfun(@(x)  mean(diff(x)),trl_raw.time); 
  period = uniquetol(period,timetol);
  assert(length(period)==1,'inconsistent sampling frequencies');
  t0 = mean(cellfun(@(x)x(1),trl_raw.time));
  t0 = round(t0,max([-ceil(log10(timetol)),0]));
  time_eq = t0 + (0:(trial_len-1))*period;
  for i=1:numel(trl_raw.time)
    trl_raw.time{i} = time_eq;
  end
end

trl_raw = ft_checkdata(trl_raw);




