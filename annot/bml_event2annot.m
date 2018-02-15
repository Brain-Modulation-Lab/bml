function annot = bml_event2annot(cfg, event)

% BML_EVENT2ANNOT creates a annot table from a events structure
%
% Use as
%   annot = bml_event2annot(cfg, event)
%   annot = bml_event2annot(cfg.roi, event)
%
% cfg.roi
% cfg.event_type  - cells of char: event types selected
% cfg.coord       - logical: should file coordinates be appended (defaults false)
% cfg.starts      - float: t0 of the event structure. If empty no time
%          correction is done
% cfg.Fs          - sampling frequency in Hz. Defaults to 1. 
% cfg.warn        - logical: should a warnings be issued. Defaults to true.  
%
% returns a annot table

if istable(cfg)
  cfg = struct('roi',cfg);
end
roi         = bml_getopt(cfg,'roi');
event_type  = bml_getopt(cfg,'event_type');
coord       = bml_getopt(cfg,'coord',false);
cfg_starts  = bml_getopt(cfg,'starts');
cfg_Fs      = bml_getopt(cfg,'Fs',1);
cfg_warn    = bml_getopt(cfg,'warn',true);

%selecting events
if isempty(event_type)
  event_type = unique({event.type});
else
  present_event_type = ismember(event_type,unique({event.type}));
  if ~all(present_event_type) && cfg_warn
    warning('selected event type %s not present. Available event types are: %s',...
      strjoin(event_type(~present_event_type)),strjoin(unique({event.type})));
  end
  event_type = event_type(present_event_type);
end

if ~isempty(roi)
  %creating raw
  roi = bml_sync_consolidate(bml_roi_confluence(roi));
  assert(height(roi)==1,"can't deal with more than one sync chunk after consolidation for now");

  annot=table();
  for i=1:length(event_type)
    i_event = event(ismember({event.type},event_type(i)));
    starts = bml_idx2time(roi,[i_event.sample])';
    ends = starts;
    type = {i_event.type}';
    value = [i_event.value]';  
    offset = [i_event.offset]';
    duration = [i_event.duration]';  
    sample = [i_event.sample]'; 
    i_annot = table(starts,ends,type,value,sample);
    %if ~isempty(offset)
    %  i_annot = [i_annot, offset];
    %end
    %if ~isempty(duration)
    %  i_annot = [i_annot, duration];
    %end
    annot = [annot; i_annot];
  end

  if coord
    annot = [annot repmat(roi(1,{'s1','t1','s2','t2','folder','name','nSamples','Fs'}),height(annot),1)];
    annot = bml_roi_table(annot);
  else
    annot = bml_annot_table(annot);
  end
  
elseif ~isempty(cfg_starts) && ~isempty(cfg_Fs)

  annot=table();
  for i=1:length(event_type)
    i_event = event(ismember({event.type},event_type(i)));
    starts = (cfg_starts+[i_event.sample] ./ cfg_Fs)';
    ends = starts;
    type = {i_event.type}';
    value = [i_event.value]';  
    offset = [i_event.offset]';
    duration = [i_event.duration]';  
    sample = [i_event.sample]'; 
    i_annot = table(starts,ends,type,value,sample);
    annot = [annot; i_annot];
  end

else
  error('Either roi or starts/Fs should be given');
  
end

annot = bml_annot_table(annot);