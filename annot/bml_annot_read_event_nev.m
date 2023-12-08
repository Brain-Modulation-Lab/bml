function events = bml_annot_read_event_nev(cfg)

% BML_ANNOT_READ_EVENT_NEV reads event annotation table from nev files
%
% Usage:
% events = bml_annot_read_event_nev(cfg);
% events = bml_annot_read_event_nev(cfg.roi);
%
% Configuration structure options:
% cfg.roi - annot: table with synchronized nev files
% cfg.detectflank - 'up', 'down' or 'both' (default)
%
% returns an events annotation table 

if istable(cfg)
    roi_nev = cfg;
    cfg = [];
else
    roi_nev = bml_getopt(cfg,'roi');
end
detectflank  = bml_getopt_single(cfg,'detectflank','both');

events = table();
for i=1:height(roi_nev)
    E=ft_read_event(fullfile(roi_nev.folder{i},roi_nev.name{i}),'detectflank',detectflank);
    hdr = ft_read_header(fullfile(roi_nev.folder{i},roi_nev.name{i}));
    cfg=[]; cfg.Fs = 1; %already in seconds
    cfg.starts = roi_nev.t1(i) - (roi_nev.s1(i)-1)./roi_nev.Fs(i);
    events_i = bml_event2annot(cfg,E);
    if ~isempty(events_i)
        events_i.value = events_i.value - 1;
        events_i.sample = round(events_i.starts .* hdr.Fs);
        events_i.file_id(:) = i;
        events_i.filename(:) = roi_nev.name(i);
        events = bml_annot_rowbind(events,events_i);
    end
end