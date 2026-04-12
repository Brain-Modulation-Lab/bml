# Creating and Loading Annotation Tables

## From scratch

```matlab
% Minimal: starts and ends only
spikes = bml_annot_table(table([1.2;1.8;2.4], [1.2;1.8;2.4], ...
  'VariableNames', {'starts','ends'}));

% With extra columns
trials = table([10;20;30], [10.5;20.5;30.5], {'go';'nogo';'go'}, ...
  'VariableNames', {'starts','ends','trial_type'});
trials = bml_annot_table(trials);
```

## From BIDS TSV (`bml_annot_read_tsv`)

BIDS event files use `onset` (seconds) and `duration` columns. `bml_annot_read_tsv` renames `onset → starts` and computes `ends = starts + duration` automatically.

```matlab
events = bml_annot_read_tsv( ...
  'sub-DM1001_ses-intraop_task-speech_events.tsv');
% Columns: id, starts, ends, duration, trial_type, response_time, ...
% Also parses sub-/ses-/task- from filename if AppendColsFromFilename=true

% Write back after sync:
bml_annot_write_tsv(events_synced, 'sub-DM1001_...-sync.tsv');
% Renames starts→onset, drops id, writes tab-delimited
```

## From FieldTrip events (`bml_event2annot`)

```matlab
ft_events = ft_read_event(fullfile(roi.folder{1}, roi.name{1}));

cfg = [];
cfg.roi = roi(strcmp(roi.filetype,'trellis'), :);
cfg.Fs  = 30000;
annot_events = bml_event2annot(cfg, ft_events);
% Columns: id, starts, ends, duration, type, value, sample
% 'sample' = raw index; starts/ends = master-clock seconds via roi

% Common shortcut:
master_events = bml_event2annot([], bml_read_event(trellis_roi));
```

## Scanning a folder (`bml_info_raw` + `bml_roi_table`)

```matlab
info = bml_info_raw(struct( ...
  'folder',   '/data/p001/s01', ...
  'filetype', {{'trellis','zoom','neuroomega'}} ));

roi = bml_roi_table(info);
% roi: one row per file, default (s1,t1,s2,t2) from OS timestamps
% Sync functions will update t1/t2 to master-clock times
```

## From NEV / WAV files

```matlab
% Events from a Ripple NEV file
cfg = []; cfg.roi = trellis_roi; cfg.detectflank = 'up';
events = bml_annot_read_event_nev(cfg);

% Peaks from a WAV audio file (for Zoom sync)
cfg = []; cfg.roi = zoom_roi; cfg.min_rph = 0.5; cfg.min_ipi = 0.05;
audio_peaks = bml_annot_read_event_wav(cfg);
```
