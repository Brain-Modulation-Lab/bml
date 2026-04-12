# Grouping, Consolidation, and Measurement

## `bml_annot_consolidate` — Merge by Criterion

Merges consecutive rows that satisfy a criterion function. The default criterion is overlap/contiguity (next row starts before the current group ends).

```matlab
% Default: merge overlapping/touching intervals (same as bml_annot_union)
cons = bml_annot_consolidate(annot);

% Same-label grouping (run-length encoding)
cfg = []; cfg.criterion = @(x) length(unique(x.label)) == 1;
cons = bml_annot_consolidate(cfg, annot);

% Fixed batch size
cfg = []; cfg.criterion = @(x) height(x) <= 4;
batches = bml_annot_consolidate(cfg, trials);

% Contiguous files with same depth (NeuroOmega pattern)
cfg = [];
cfg.criterion = @(x) (length(unique(x.depth))==1) && ...
  (abs((max(x.ends)-min(x.starts)) - sum(x.duration)) < 1e-2);
cons_depth = bml_annot_consolidate(cfg, neuro_info);
```

Output always includes: `cons_duration`, `id_starts`, `id_ends`, `cons_n`.

---

## `bml_annot_blocks` — Run-Length Encoding

Groups consecutive rows with the **same label** into blocks, and records **transitions** between blocks.

```matlab
cfg = []; cfg.label = 'trial_type';
[blocks, edges] = bml_annot_blocks(cfg, trial_annot);
% blocks: one row per contiguous run of the same label
% edges:  one row per label transition (pre_label, post_label)

% Create analysis windows around transitions
cfg = []; cfg.label = 'state'; cfg.win_edges = 2.0; % ±2 s
[blocks, edges] = bml_annot_blocks(cfg, behavioral_coding);

% Group by session
cfg = []; cfg.label = 'depth'; cfg.group_by = 'session_id';
[blocks, edges] = bml_annot_blocks(cfg, recording_info);
```

---

## `bml_annot_shadow` — Fill the Gaps

Creates annotations that occupy the **space between** events. Primary use: pre-stimulus baselines, post-response silence windows.

```matlab
% Pre-stimulus baseline: 1.5 s window ending at each stimulus onset
cfg = [];
cfg.direction    = -1;   % look into the past
cfg.gap_duration = 0;    % shadow touches the event
cfg.max_duration = 1.5;  % cap at 1.5 s
baseline = bml_annot_shadow(cfg, stim_events);

% Post-response silence
cfg = []; cfg.direction = 1; cfg.gap_duration = 0.2; cfg.max_duration = 2.0;
post = bml_annot_shadow(cfg, response_events);

% Always restrict to session window after (last shadow → ±inf)
baseline = bml_annot_filter(baseline, session_window);
```

---

## `bml_annot_coverage` — Measuring Overlap

$$\text{coverage}(y_j) = \frac{\sum_i |x_i \cap y_j|}{|y_j|}$$

Returns 0–1: fraction of each $y$ interval covered by $x$.

```matlab
% Fraction of each trial covered by artifacts
cov = bml_annot_coverage(artifacts, trials);
clean_trials = trials(cov.coverage < 0.10, :);  % < 10% artifact

% Per-channel coverage
cfg = []; cfg.groupby_x = 'channel';
cov_ch = bml_annot_coverage(cfg, chan_artifacts, trials);

% Custom column name
cfg = []; cfg.colname = 'artifact_fraction';
cov = bml_annot_coverage(cfg, artifacts, trials);
```

---

## `bml_annot_overlap` — Conflict Detection

Finds all **pairs** in the same table that overlap each other. Required: `bml_annot_intersect` requires `y` to be overlap-free.

```matlab
% Validate before using as y in intersect
ovlp = bml_annot_overlap(annot);
assert(isempty(ovlp), 'Table has %d overlapping pairs', height(ovlp));

% Find and fix
ovlp = bml_annot_overlap(my_events);
if ~isempty(ovlp)
  my_events = bml_annot_union(my_events);  % merge the conflicts
end
```
