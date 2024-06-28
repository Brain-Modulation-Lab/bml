function stim = bml_annot_read_stim_nev(cfg)

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


stim = table();
for i=1:height(roi_nev)
    
    filename = fullfile(roi_nev.folder{i},roi_nev.name{i});
    % 'nosave' prevents the automatic conversion of
    % the .nev file as a .mat file
    orig = openNEV(filename, 'nosave');
    
    fs             = orig.MetaTags.SampleRes; % sampling rate
    timestamps     = orig.Data.Spikes.TimeStamp;
    electrode      = orig.Data.Spikes.Electrode;
    stimTimes = double(timestamps)./double(fs); % express in seconds

    E = struct();
    for k=1:numel(timestamps)
      E(k).offset    = 0;
      E(k).duration  = 0;
      E(k).value     = electrode(k);
      E(k).sample    = stimTimes(k);
      E(k).type      = 'stim';
    end
    
    elecInfo = struct2table(orig.ElectrodesInfo);
    elecInfo = elecInfo(~cellfun('isempty', {orig.ElectrodesInfo.ElectrodeID}),:);
    
    if numel(timestamps) > 0 
      hdr = ft_read_header(fullfile(roi_nev.folder{i},roi_nev.name{i}));
      cfg=[]; cfg.Fs = 1; %already in seconds
      cfg.starts = roi_nev.t1(i) - (roi_nev.s1(i)-1)./roi_nev.Fs(i);
      events_i = bml_event2annot(cfg,E);
      if ~isempty(events_i)
          events_i.stimchannel = events_i.value;
          events_i.sample = round(events_i.starts .* hdr.Fs);
          events_i.file_id(:) = i;
          events_i.filename(:) = roi_nev.name(i);
          stim = bml_annot_rowbind(stim,events_i);
      end
    end

end

