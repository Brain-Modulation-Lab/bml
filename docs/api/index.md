# Function Reference

## Annotation functions

### Construction & I/O

| Function | Description |
|----------|-------------|
| `bml_annot_table(x)` | Create annotation table from any source (table, struct, numeric matrix) |
| `bml_roi_table(x)` | Create ROI table; adds `id`, `starts`, `ends`, `duration`, validates file metadata |
| `bml_annot_read_tsv(file)` | Load BIDS-format TSV into annotation table |
| `bml_annot_write_tsv(annot, file)` | Write annotation table to BIDS TSV |
| `bml_info_raw(cfg)` | Scan disk folder, return file metadata table |

### Interval operations

| Function | Formula | Description |
|----------|---------|-------------|
| `bml_annot_extend(annot, e1, e2)` | $[a_1 - e_1,\; a_2 + e_2]$ | Dilate intervals |
| `bml_annot_filter(annot, mask)` | — | Keep rows overlapping mask |
| `bml_annot_filterout(annot, mask)` | — | Remove rows with coverage > threshold |
| `bml_annot_intersect(x, y)` | $[\max(a_1,b_1), \min(a_2,b_2)]$ | Clip to overlap |
| `bml_annot_union(x, y)` | $[\min(a_1,b_1), \max(a_2,b_2)]$ | Merge overlapping intervals |
| `bml_annot_difference(x, y)` | $x \setminus y$ | Remove y from x |

### Grouping & statistics

| Function | Description |
|----------|-------------|
| `bml_annot_consolidate(cfg, annot)` | Merge adjacent rows meeting a criterion |
| `bml_annot_blocks(cfg, annot)` | Run-length encode a label column → blocks + transitions |
| `bml_annot_shadow(annot)` | Create gap-filling baseline periods |
| `bml_annot_coverage(x, y)` | Fraction of each `y` interval covered by `x` |
| `bml_annot_overlap(annot)` | Return all overlapping pairs (conflict detection) |
| `bml_annot_describe(cfg, annot)` | Summary stats (mean, std, count, median, IQR) per group |

### Joins & feature extraction

| Function | Description |
|----------|-------------|
| `bml_annot_left_join(left, right, keys)` | SQL-style left join on key columns |
| `bml_annot_transfer(cfg, annot, source)` | Assign label from overlapping source row |
| `bml_annot_calculate(cfg, annot, name, fn)` | Apply function to raw data in each window |
| `bml_annot_detect(cfg, raw)` | Threshold-based event detection |
| `bml_annot_match(cfg, data, template)` | Template matching in continuous signal |

### Transformation & utilities

| Function | Description |
|----------|-------------|
| `bml_annot_t0(annot, t0)` | Shift times: `starts = starts - t0` |
| `bml_annot_rowbind(A, B, ...)` | Vertically concatenate annotation tables |
| `bml_annot_conform_to(template, annot)` | Add missing columns (NaN/empty) to match schema |
| `bml_annot_rename(annot, old, new)` | Rename columns |
| `bml_annot_sample(annot, n)` | Random row subsample |

### Encoding & visualization

| Function | Description |
|----------|-------------|
| `bml_annot2raw(annot, roi)` | Convert events to binary signal (FieldTrip `raw`) |
| `bml_raw2annot(raw)` | Extract time metadata from FieldTrip raw |
| `bml_annot2spike(annot, roi)` | Convert to FieldTrip spike structure |
| `bml_event2annot(cfg, events)` | Convert FieldTrip events to annotation table |
| `bml_annot_plot(cfg, annot)` | Timeline visualization |

---

## Synchronization functions

### Building ROI / chunking

| Function | Description |
|----------|-------------|
| `bml_roi_table(x)` | Build ROI table from file metadata |
| `bml_chunk_sessions(session, n_or_t, dur)` | Split session into sync windows |

### Analog sync

| Function | Description |
|----------|-------------|
| `bml_sync_analog(cfg)` | Two-stage envelope + LPF xcorr |
| `bml_timealign(cfg, master, slave)` | Single-pass xcorr offset finder |
| `bml_timewarp(cfg, master, slave)` | Nelder-Mead linear drift correction |

### Event-based sync

| Function | Description |
|----------|-------------|
| `bml_sync_neuroomega_event(cfg)` | NeuroOmega TTL event matching |
| `bml_sync_audio_event(cfg)` | Audio peak → digital event matching |
| `bml_sync_digital(cfg, master, slave)` | Psychtoolbox/digital event matching |
| `bml_sync_match_events(cfg, e1, e2)` | Core DP event alignment |
| `bml_timealign_annot(cfg, master, slave)` | Brute-force + fminsearch event aligner |
| `bml_timewarp_annot(cfg, master, slave)` | Event-based warp |

### Consolidation & validation

| Function | Description |
|----------|-------------|
| `bml_sync_consolidate(cfg)` | Merge chunks → 1 row per file |
| `bml_sync_check(sync_roi)` | Validate residuals, print summary |

### Coordinate conversion

| Function | Description |
|----------|-------------|
| `bml_idx2time(sync_roi, s)` | Sample index → master-clock seconds |
| `bml_time2idx(sync_roi, t)` | Master-clock seconds → sample index |
| `bml_annot2coord(annot, roi)` | Add `s1`, `t1`, `s2`, `t2` to annotation |
| `bml_roi2coord(roi)` | Extract coordinate array from ROI |

---

## Common `cfg` fields

| Field | Functions that use it | Meaning |
|-------|-----------------------|---------|
| `roi` | most sync functions | ROI table to process |
| `master_events` | event sync functions | Reference event list |
| `timewarp` | sync functions | Enable linear drift correction |
| `scan` | `bml_timealign_annot` | Coarse search range (s) |
| `scan_step` | `bml_timealign_annot` | Grid step (s) |
| `timetol` | sync + consolidation | Acceptable residual (s) |
| `diagnostic_plot` | sync functions | Show alignment figure |
| `groupby` | `bml_annot_describe` | Grouping column |
| `select` | `bml_annot_transfer` | Columns to copy |
| `overlap` | `bml_annot_filterout` | Fraction threshold |
