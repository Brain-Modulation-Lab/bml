# Signal Encoding and Visualization

## `bml_annot2raw` — Annotations → Binary Signal

Converts an annotation table to a continuous `FT_DATATYPE_RAW` signal. Each sample is 1 if covered by an annotation, 0 otherwise. With `cfg.count=true`, the signal counts overlapping annotations.

```matlab
% Binary stimulus-presence signal (for cross-correlation)
cfg = []; cfg.roi = trellis_roi; cfg.label = 'stim_ch';
stim_raw = bml_annot2raw(cfg, stim_annotations);

% Count overlapping artifacts per sample
cfg = []; cfg.count = true;
artifact_count = bml_annot2raw(cfg, artifacts, trellis_roi);

% One channel per unique label value
cfg = []; cfg.label_colname = 'trial_type';
coding_raw = bml_annot2raw(cfg, trial_annotations, roi);
```

## `bml_raw2annot` — Raw → Annotation Metadata

Extracts time bounds from a raw FieldTrip structure back into annotation metadata.

```matlab
annot_meta = bml_raw2annot([], lfp_raw);
% Columns: starts, ends, trial, s1, t1, s2, t2, Fs, nSamples
```

## `bml_annot2spike` — Events → Spike Structure

Converts an annotation table to a FieldTrip `ft_datatype_spike` structure.

```matlab
cfg = []; cfg.roi = trellis_roi;
spike_data = bml_annot2spike(cfg, spike_annotations);
% spike_data.timestamp{unit} = spike times
% spike_data.label = {'G14_unit1', 'G14_unit2', ...}
```

---

## `bml_annot_plot` — Visualization

Plots annotation intervals as horizontal line segments.

```matlab
% One line per annotation id (default)
bml_annot_plot([], trial_windows);

% Group by column on y-axis
cfg = []; cfg.y = 'trial_type';
bml_annot_plot(cfg, trial_windows);

% Facet by session (one subplot per session)
cfg = []; cfg.y = 'channel'; cfg.facet = 'session_id';
bml_annot_plot(cfg, lfp_epochs);
```
