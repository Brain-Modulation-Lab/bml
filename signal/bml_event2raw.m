function raw = bml_event2raw(cfg, event)

% BML_EVENT2RAW creates a raw of zeros with ones at event times
%
% Use as
%   raw = bml_event2raw(cfg, event)
%   raw = bml_event2raw(roi, event)
%
% cfg.roi
% cfg.event_type - cells of char: event types selected
%
% returns a raw

if istable(cfg)
  cfg = struct('roi',cfg);
end
roi         = bml_getopt(cfg,'roi');
event_type  = bml_getopt(cfg,'event_type');

%selecting events
if isempty(event_type)
  event_type = unique({event.type});
else
  event_type = event_type(ismember(event_type,unique({event.type})));
end

%creating raw
roi = bml_sync_consolidate(bml_roi_confluence(roi));
assert(height(roi)==1,"can't deal with more than one sync chunk after consolidation for now");

raw=[];
raw.time={bml_idx2time(roi,roi.s1:roi.s2)};
raw.trial={zeros(length(event_type),size(raw.time{1},2))};
raw.label=event_type;
raw.fsample=roi.Fs;

for i=1:length(event_type)
  i_event = event(ismember({event.type},event_type(i)));
  raw.trial{1}(i,[i_event.sample])=1;
end
