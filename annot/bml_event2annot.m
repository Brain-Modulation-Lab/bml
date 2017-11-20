function annot = bml_event2annot(cfg, event)

% BML_EVENT2ANNOT creates a annot table from a events structure
%
% Use as
%   annot = bml_event2annot(cfg, event)
%   annot = bml_event2annot(cfg, event)
%
% cfg.roi
% cfg.event_type - cells of char: event types selected
% cfg.coord - logical: should file coordinates be appended (defaults false)
%
% returns a annot table

if istable(cfg)
  cfg = struct('roi',cfg);
end
roi         = bml_getopt(cfg,'roi');
event_type  = bml_getopt(cfg,'event_type');
coord       = bml_getopt(cfg,'coord',false);

%selecting events
if isempty(event_type)
  event_type = unique({event.type});
else
  event_type = event_type(ismember(event_type,unique({event.type})));
end

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


