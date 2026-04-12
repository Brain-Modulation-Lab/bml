# Joining Tables and Computing Features

## `bml_annot_left_join` — Key-Based Join

Standard relational left join. All rows of the left table are preserved; matching columns from the right table are added.

```matlab
% Add subject/session metadata to each trial
cfg = []; cfg.keys = {'session_id'};
trials_full = bml_annot_left_join(cfg, trials, session_metadata);

% Add per-electrode impedance to spike annotations
cfg = []; cfg.keys = {'channel'};
spikes_full = bml_annot_left_join(cfg, spikes, electrode_info);
```

---

## `bml_annot_transfer` — Temporal Overlap Join

For each row in `annot`, find which rows in `transfer` **contain it** (by time overlap) and copy selected columns. Used to assign epoch-level labels to individual events within the epoch.

```matlab
% Assign trial condition to each spike
cfg = []; cfg.select = {'trial_id', 'condition', 'response'};
spikes_labeled = bml_annot_transfer(cfg, spikes, trial_epochs);
% Spikes not inside any trial get NaN for transferred columns

% Require ≥ 50% overlap
cfg.overlap = 0.5;
```

---

## `bml_annot_calculate` — Feature Extraction

Applies arbitrary scalar functions to raw signal data over each epoch. Each function receives a `FT_DATATYPE_RAW` segment and must return a scalar.

```matlab
% Define features
rms_fn  = @(raw) sqrt(mean(raw.trial{1}(1,:).^2));
peak_fn = @(raw) max(raw.trial{1}(1,:)) - min(raw.trial{1}(1,:));
pwr_fn  = @(raw) 10*log10(mean(raw.trial{1}(1,:).^2) + eps);

% Compute over each trial window
cfg = []; cfg.roi = hg_roi;
results = bml_annot_calculate(cfg, trial_windows, ...
  'rms',       rms_fn, ...
  'peak2peak', peak_fn, ...
  'log_power', pwr_fn);
% results has all original columns plus rms, peak2peak, log_power
```

---

## `bml_annot_describe` — Descriptive Statistics

Computes mean, median, std, min, max, count for all numeric columns, optionally grouped.

```matlab
cfg = []; cfg.groupby = 'trial_type';
stats = bml_annot_describe(cfg, results);
% Returns long-format table: trial_type | variable | mean | std | ...
```

---

## `bml_annot_detect` — Threshold Detection

Detects epochs where a signal crosses a threshold. Finds peaks above the upper threshold, then expands to the nearest zero-crossing of the lower threshold.

```matlab
cfg = [];
cfg.threshold  = [1.0, 3.0];  % [lower, upper] in signal units
cfg.channel    = 'G14';
cfg.max_annots = 500;
bursts = bml_annot_detect(cfg, hg_envelope_raw);
% bursts: starts, ends, env_max, trial, label

% Single threshold (upper only)
cfg = []; cfg.threshold = 3.0;
detections = bml_annot_detect(cfg, envelope_raw);
```
