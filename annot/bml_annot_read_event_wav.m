function events = bml_annot_read_event_wav(cfg)

% BML_ANNOT_READ_EVENT_WAV reads events annotation table from wav files
%
% Usage:
% events = bml_annot_read_event_nev(cfg);
% events = bml_annot_read_event_nev(cfg.roi);
%
% Configuration structure options:
% cfg.roi - annot: table with synchronized nev files
% cfg.detectflank - 'up', 'down' or 'both' (default)
% cfg.flip_polarity - bool, 
%
% returns an events annotation table 

if istable(cfg)
    roi = cfg;
    cfg = [];
else
    roi = bml_getopt(cfg,'roi');
end

detectflank = bml_getopt_single(cfg,'detectflank','both');

min_ipi     = bml_getopt(cfg,'min_ipi',0.05);
min_rph     = bml_getopt(cfg,'min_rph',0.25);
flip_polarity = bml_getopt(cfg,'flip_polarity',0);

assert(~isempty(roi),'roi required');
is_roi = all(ismember(roi.Properties.VariableNames,{'s1','t1','Fs'}));

events = table();
for i=1:height(roi)
  
    %getting events
    cfg1=[];
    cfg1.roi = roi(i,:);
    audio = bml_load_continuous(cfg1);
    audio1 = audio.trial{1}(1,:);
    if flip_polarity; audio1 = audio1 .* -1.0; end
    MinPeakDistance = min_ipi;
    min_peak_height = max(audio1)*min_rph;
    [~,locs_max] = findpeaks(audio1,audio.fsample,...
    'MinPeakHeight',min_peak_height,'MinPeakDistance',MinPeakDistance,'MinPeakProminence',min_peak_height * 0.5);
    min_peak_height = max(-audio1)*min_rph;
    [~,locs_min] = findpeaks(-audio1,audio.fsample,...
    'MinPeakHeight',min_peak_height,'MinPeakDistance',MinPeakDistance,'MinPeakProminence',min_peak_height * 0.5);
    locs = sort([locs_max, locs_min]);

    if isempty(locs) 
        warning(['no events found in wav file' roi.name{i}])
        continue
    end

    %creating annot table with events
    if is_roi
        starts = (roi.t1(i) - (roi.s1(i)-1)./roi.Fs(i) + locs)';
    else
        starts = (roi.starts(i) + locs)';
    end

    ends = starts;
    i_slave_events=bml_annot_table(table(starts,ends));
    i_slave_events.type = repmat({'audio'},[height(i_slave_events),1]);
    audio1 = smooth(audio1,min_ipi*audio.fsample);
    i_slave_events.value = (audio1(ceil(locs .* audio.fsample)) > 0) .* 1.0;
    i_slave_events.sample = round(locs.*audio.fsample)';
    i_slave_events.filename(:) = roi.name(i);

    events = bml_annot_rowbind(events,i_slave_events);

end






% 
% events = table();
% for i=1:height(roi_nev)
%     E=ft_read_event(fullfile(roi_nev.folder{i},roi_nev.name{i}),'detectflank',detectflank);
%     hdr = ft_read_header(fullfile(roi_nev.folder{i},roi_nev.name{i}));
%     cfg=[]; cfg.Fs = 1; %already in seconds
%     cfg.starts = roi_nev.t1(i) - (roi_nev.s1(i)-1)./roi_nev.Fs(i);
%     events_i = bml_event2annot(cfg,E);
%     if ~isempty(events_i)
%         events_i.value = events_i.value - 1;
%         events_i.sample = round(events_i.starts .* hdr.Fs);
%         events_i.file_id(:) = i;
%         events_i.filename(:) = roi_nev.name(i);
%         events = bml_annot_rowbind(events,events_i);
%     end
% end