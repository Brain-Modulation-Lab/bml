# Set Operations on Time Intervals

All set operations preserve interval algebra semantics. The overlap condition for two intervals $[a_1,a_2]$ and $[b_1,b_2]$ is:

$$a_1 < b_2 \;\;\text{AND}\;\; a_2 > b_1$$

---

## `bml_annot_extend` — Dilation / Erosion

Adds (positive) or removes (negative) time on either side of every row.

$$\text{starts}_{\text{new}} = \text{starts} - \text{ext1}, \quad \text{ends}_{\text{new}} = \text{ends} + \text{ext2}$$

```matlab
% Add 0.5 s context on each side
windows = bml_annot_extend(trials, 0.5);

% Pre-stimulus baseline: 0.5 s ending at onset
baseline = bml_annot_extend(stim_events, 0.5, 0);

% Shrink artifact windows by 50 ms (conservative)
trimmed = bml_annot_extend(artifacts, -0.05);

% Asymmetric: 1 s before, 2 s after
win = bml_annot_extend(stim_events, 1.0, 2.0);
```

---

## `bml_annot_filter` / `bml_annot_filterout` — Selection

**`filter`**: keep rows of `annot` that **touch** `filter_annot`.  
**`filterout`**: keep rows that **do not touch** `filter_annot`.

`cfg.overlap` (default 0): require that fraction of the row be covered.

```matlab
% Keep trials within the session window
trials_in = bml_annot_filter(trials, session);

% Remove trials overlapping artifacts
clean = bml_annot_filterout(trials, artifacts);

% Keep trials ≥ 50% inside the analysis window
cfg = []; cfg.overlap = 0.5;
mostly_inside = bml_annot_filter(cfg, trials, analysis_window);
```

:::{note}
`bml_annot_filter` **selects whole rows** — it does not clip. Use `bml_annot_intersect` to also clip to the window boundary.
:::

---

## `bml_annot_intersect` — Clip to Overlap Region

Returns the actual overlap regions, with parent IDs from both tables.

$$[a_1,a_2] \cap [b_1,b_2] = [\max(a_1,b_1),\;\min(a_2,b_2)]$$

```matlab
% Clip trials to session window; output has x_id and y_id columns
clipped = bml_annot_intersect(trials, session_windows);

% Keep extra columns from both tables
cfg = []; cfg.keep = 'both';   % or 'x', 'y', 'none'
info = bml_annot_intersect(cfg, trials, artifacts);

% Per-channel intersection
cfg = []; cfg.groupby = 'channel';
per_ch = bml_annot_intersect(cfg, spikes, artifacts_per_channel);
```

---

## `bml_annot_union` — Merge Overlapping Intervals

Merges touching or overlapping intervals from one or two tables.

```matlab
% Combine artifact lists from two annotators
all_art = bml_annot_union(artifacts_A, artifacts_B);

% Self-union: collapse overlaps within one table
clean = bml_annot_union(dirty_annot);

% Wider tolerance: gaps < 10 ms count as touching
cfg = []; cfg.timetol = 0.01;
merged = bml_annot_union(cfg, artifacts_A, artifacts_B);
```

---

## `bml_annot_difference` — Set Subtraction

Returns $x \setminus y$: the parts of $x$ not covered by $y$. May split $x$ intervals into pieces; original $x$ columns are preserved on every fragment.

```matlab
% Remove artifact sub-windows from trial windows
clean = bml_annot_difference(trial_windows, artifacts);
% clean.x_id_ links each fragment back to the original trial

% Per-channel (artifacts labelled by channel)
cfg = []; cfg.groupby_x = 'channel'; cfg.groupby_y = 'channel';
clean_ch = bml_annot_difference(cfg, lfp_windows, chan_artifacts);
```

Five geometric cases handled internally:

| $y$ relative to $x$ | Result |
|---------------------|--------|
| $y$ fully covers $x$ | Row removed |
| $y$ clips start of $x$ | Fragment $[y.\text{ends},\; x.\text{ends}]$ |
| $y$ clips end of $x$ | Fragment $[x.\text{starts},\; y.\text{starts}]$ |
| $y$ bisects $x$ | Two fragments |
| No overlap | $x$ row kept as-is |
