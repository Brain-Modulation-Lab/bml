# BML Synchronization Guide

**Brain Modulation Laboratory — Massachusetts General Hospital**

This guide explains the synchronization subsystem of the BML toolbox: how multi-device recordings are brought onto a common time axis, how annotation tables are structured, and how each core function works internally.

---

## Table of Contents

1. [The Synchronization Problem](#1-the-synchronization-problem)
2. [Annotation Tables](#2-annotation-tables)
   - [Schema](#21-schema)
   - [ROI Tables](#22-roi-tables)
   - [Key Manipulation Functions](#23-key-manipulation-functions)
3. [The Coordinate System: s1, t1, s2, t2](#3-the-coordinate-system-s1-t1-s2-t2)
4. [Coordinate Conversion](#4-coordinate-conversion)
   - [bml_idx2time](#41-bml_idx2time)
   - [bml_time2idx](#42-bml_time2idx)
5. [Continuous Signal Alignment](#5-continuous-signal-alignment)
   - [bml_timealign — cross-correlation](#51-bml_timealign--cross-correlation)
   - [bml_timewarp — linear warp optimization](#52-bml_timewarp--linear-warp-optimization)
6. [Event-Based Alignment](#6-event-based-alignment)
   - [bml_timealign_annot — brute-force + fminsearch](#61-bml_timealign_annot--brute-force--fminsearch)
   - [bml_sync_match_events — dynamic programming](#62-bml_sync_match_events--dynamic-programming)
7. [High-Level Sync Entry Points](#7-high-level-sync-entry-points)
   - [bml_sync_analog](#71-bml_sync_analog)
   - [bml_sync_audio_event](#72-bml_sync_audio_event)
   - [bml_sync_digital / bml_sync_neuroomega_event](#73-bml_sync_digital--bml_sync_neuroomega_event)
8. [Consolidation](#8-consolidation)
9. [Full Workflow Diagram](#9-full-workflow-diagram)

---

## 1. The Synchronization Problem

A typical BML recording session involves several devices running in parallel:

- **Trellis** (master neural recorder)
- **Zoom** (audio recorder)
- **NeuroOmega** (microelectrode recorder)
- **NSX/Blackrock** files

Each device has its own internal clock. Two systematic errors arise:

| Error | Description | Magnitude |
|---|---|---|
| **Time offset** | Devices started at different absolute times | Seconds to minutes |
| **Clock drift** | Devices run at slightly different rates (e.g., one is 2 ppm fast) | Microseconds/second, accumulates to milliseconds over hours |

The sync subsystem corrects both, producing a unified time axis (the master's clock) that all devices are mapped to.

---

## 2. Annotation Tables

### 2.1 Schema

Annotation tables are standard MATLAB `table` objects with a fixed schema enforced by `bml_annot_table()`. Every annotation table has these columns in this order:

| Column | Type | Description |
|---|---|---|
| `id` | integer | Row identifier, auto-assigned by sorting on `starts` (1-indexed, unique) |
| `starts` | double (s) | Start time in seconds |
| `ends` | double (s) | End time in seconds |
| `duration` | double (s) | Auto-computed as `ends - starts`; never set manually |
| *(user columns)* | any | Any additional columns are preserved after the core four |

`duration` is always recomputed by `bml_annot_table()` and cannot be overridden. `id` is always reassigned in sorted order; do not use it as a stable identifier across function calls.

```matlab
% Creating an annotation table
t = table([1.0; 5.0], [2.5; 8.0], 'VariableNames', {'starts','ends'});
annot = bml_annot_table(t);
% Result: id=[1;2], starts=[1.0;5.0], ends=[2.5;8.0], duration=[1.5;3.0]
```

### 2.2 ROI Tables

An **ROI table** (Region Of Interest) is an annotation table extended with file-level information needed for synchronization. Created by `bml_roi_table()`.

**Additional required columns:**

| Column | Type | Description |
|---|---|---|
| `folder` | string | Directory path to the file |
| `name` | string | Filename |
| `nSamples` | integer | Total number of samples in the file |
| `Fs` | double | Nominal sampling frequency (Hz) |
| `filetype` | string | e.g. `'trellis'`, `'neuroomega'`, `'zoom'` |
| `chantype` | string | e.g. `'analog'`, `'digital'` |
| `s1` | integer | First sample index used as reference |
| `t1` | double (s) | Absolute time of sample `s1` (master clock) |
| `s2` | integer | Second sample index used as reference |
| `t2` | double (s) | Absolute time of sample `s2` (master clock) |

The `(s1, t1, s2, t2)` quartet is the core sync state for each file — see [Section 3](#3-the-coordinate-system-s1-t1-s2-t2).

**Default values before sync:**
- `s1 = 1`, `t1 = starts + 0.5/Fs` (midpoint of first sample)
- `s2 = nSamples`, `t2 = ends - 0.5/Fs` (midpoint of last sample)

### 2.3 Key Manipulation Functions

| Function | What it does |
|---|---|
| `bml_annot_table(x)` | Constructor — enforces schema, auto-assigns `id` and `duration`, sorts by `starts` |
| `bml_annot_overlap(cfg, a)` | Returns all pairs of rows in `a` whose intervals overlap (within `timetol`) |
| `bml_annot_intersect(cfg, x, y)` | Returns the set of intervals where `x` and `y` overlap; merges columns from both tables |
| `bml_annot_union(cfg, x, y)` | Concatenates `x` and `y`, then consolidates touching/overlapping rows |
| `bml_annot_difference(cfg, x, y)` | Subtracts all intervals in `y` from those in `x` |
| `bml_annot_filter(cfg, a, f)` | Keeps only rows of `a` that intersect with regions in `f` |
| `bml_annot_consolidate(cfg, a)` | Merges contiguous or overlapping rows into single rows (run-length encoding) |
| `bml_annot_extend(a, ext1, ext2)` | Shifts `starts -= ext1` and `ends += ext2`; useful for adding temporal buffers |
| `bml_roi_confluence(cfg)` | Sets junction times between adjacent ROI file chunks so they tile seamlessly |

**`bml_annot_consolidate`** is worth understanding in detail. It merges rows using a configurable criterion (default: any overlap or adjacency) and records:
- `cons_n`: number of original rows merged
- `id_starts`, `id_ends`: first and last original `id` values in the merge group
- `cons_duration`: sum of individual durations (vs. `duration = ends - starts` of the merged interval)

---

## 3. The Coordinate System: s1, t1, s2, t2

Every file's sync state is encoded as **two reference points** that define a linear map from sample index to absolute time:

```
(s1, t1)  —  sample s1 occurred at master-clock time t1
(s2, t2)  —  sample s2 occurred at master-clock time t2
```

The times `t1` and `t2` are **sample midpoint times**: a sample at index `i` spans the interval `[t(i) - 0.5/Fs, t(i) + 0.5/Fs]`. This is why default values use `±0.5/Fs` offsets from file boundaries.

The full linear mapping is:

```
Fs_eff = (s2 - s1) / (t2 - t1)          % effective (possibly warped) sample rate
offset = (s2·t1 - t2·s1) / (s2 - s1)   % time-axis intercept

time(idx) = idx / Fs_eff - 0.5/Fs_eff + offset
```

Before synchronization, `Fs_eff` equals the nominal `Fs` and `offset` is derived from the file's OS timestamp (unreliable). After synchronization, `t1` and `t2` are updated to reflect where those samples actually fall on the master clock. If warping was applied, `Fs_eff` will differ slightly from the nominal `Fs`.

**Why two points instead of one offset?**
A single time offset corrects the clock start but not drift. Two points allow both an offset and a rate correction to be encoded in the same structure, with no extra fields needed.

---

## 4. Coordinate Conversion

### 4.1 `bml_idx2time`

Converts sample indices to absolute (master-clock) times.

```matlab
time = bml_idx2time(cfg, idx)
time = bml_idx2time(cfg, idx, skipFactor)  % for Blackrock NPMK downsampled data
```

`cfg` can be a struct or a single-row (or multi-row) ROI table.

**Core formula** (from `sync/bml_idx2time.m`, line 74):
```matlab
time = double(idx)/Fs - 0.5/Fs + (s2*t1 - t2*s1)/(s2 - s1);
```

Derivation step by step:
1. `double(idx)/Fs` — position of sample `idx` in seconds from the file start
2. `- 0.5/Fs` — shift to sample midpoint (samples are 0-indexed in continuous time)
3. `+ (s2·t1 - t2·s1)/(s2-s1)` — add the intercept of the `(s1,t1)→(s2,t2)` line

**Multi-row support:** If `cfg` is a table with multiple rows (split sync, e.g. a file synced in two independent chunks), each row's `(s1,s2)` range must be non-overlapping. The function loops over rows and applies the correct linear mapping for each subset of `idx`.

**skipFactor:** Used for Blackrock files where the NPMK package returns downsampled indices. Adjusts `s1`, `s2`, `t1`, `t2` before applying the formula:
```
s1_adj = ceil(s1 / skipFactor)
t1_adj = t1 + (skipFactor - 1) * 0.5 / Fs
```

### 4.2 `bml_time2idx`

Inverse of `bml_idx2time`. Converts master-clock times to sample indices.

```matlab
idx = bml_time2idx(cfg, time)
```

**Core formula** (inverse of above):
```matlab
idx = round( (t2·s1 - s2·t1 + (s2-s1)·time) / (t2 - t1) );
```

Times are rounded to 1 nanosecond (`pTT = 9` decimal places) before inversion to avoid floating-point accumulation errors.

---

## 5. Continuous Signal Alignment

### 5.1 `bml_timealign` — cross-correlation

Finds the time offset (`slave_delta_t`) needed to align a slave signal to a master signal.

```matlab
[slave_delta_t, max_corr, master, slave] = bml_timealign(cfg, master, slave)
```

Both `master` and `slave` are `FT_DATATYPE_RAW` structures with a single trial and channel.

**Algorithm:**

```
1. Compute scan range
   max_scan_range = [mc.t1 - sc.t2,  mc.t2 - sc.t1]
   (the widest possible shift before files stop overlapping)
   If files don't overlap → return NaN.

2. Pad/crop both signals to the full correlation time window
   (bml_pad adds zeros outside the file boundary)

3. Resample both to cfg.resample_freq (default 10000 Hz)
   Slave is resampled to master's time grid via linear interpolation.

4. Preprocess — two methods:
   'envelope' (default):
       → compute analytic signal, take absolute value
       → downsample to cfg.env_freq (default 100 Hz)
       → try_polarity = false  (envelope is always positive)
   'lpf':
       → 4th-order zero-phase Butterworth low-pass at cfg.lpf_freq (default 4000 Hz)
       → try_polarity = true   (DC-coupled signals can be inverted)

5. Normalize
   master = (master - median(master)) / robust_std(master)
   slave  = (slave  - median(slave))  / robust_std(slave)

6. Cross-correlate
   [corr, lag] = xcorr(master, slave, floor(max(|scan|)·Fs), 'coeff')
   slave_delta_t = lag(argmax(corr)) / Fs

7. If try_polarity: also try (-slave); keep whichever gives higher peak.
```

`robust_std` uses the 16th–84th percentile range (≈ 1σ for Gaussian) to avoid outliers dominating the normalization.

**Key parameters:**

| Parameter | Default | Description |
|---|---|---|
| `cfg.resample_freq` | 10000 Hz | Common frequency for cross-correlation |
| `cfg.method` | `'envelope'` | `'envelope'` or `'lpf'` |
| `cfg.env_freq` | 100 Hz | Envelope downsampling frequency |
| `cfg.lpf_freq` | 4000 Hz | Low-pass cut frequency |
| `cfg.scan` | `max_scan_range` | `[−a, b]` in seconds; search window |
| `cfg.penalty_tau` | — | Soft bound on `slave_delta_t` (hill-function penalty) |

### 5.2 `bml_timewarp` — linear warp optimization

Applies a linear time warp to slave to maximize correlation with master, correcting for clock drift.

```matlab
warpedcoords = bml_timewarp(cfg, master, slave)
```

**Warp model:**

```
w(t) = wt0 + pivot_time + (t - pivot_time) · ws1
```

- `wt0`: additional time shift (seconds) around the pivot
- `ws1`: time stretch factor (`ws1 > 1` slows the clock, `ws1 < 1` speeds it up; `ws1 = 1` = no drift)
- `pivot_time`: midpoint of the overlapping region (fixed reference point)

**Algorithm:**

```
1. Call bml_timealign → get slave_delta_t and pre-processed signals
   Update sc.t1 += slave_delta_t, sc.t2 += slave_delta_t

2. Compute overlap region: ovlp = [max(mc.t1, sc.t1),  min(mc.t2, sc.t2)]
   pivot_time = mean(ovlp)

3. Record cropped slave coordinates (crop_sc): sample range and times
   at the overlap boundaries.

4. Crop both signals to the overlap region.

5. Define cost function:
   f(t) = interp1(slave.time, slave.signal, t, 'PCHIP', 0)  % slave interpolant
   p    = master.signal

   cost([wt0, ws1]) =
       −dot(f(w(t)), p) / dot0                           % negative normalized correlation
       + (wt0 / penalty_wt0_dur)²                        % shift penalty
       + ((ws1 − 1) / penalty_ws1)⁴                      % stretch penalty

   penalty_wt0_dur = max(penalty_wt0_min, ovlp_duration · |ws1 − 1|)
     (adapts to prevent optimizer from escaping during early iterations)

6. Minimize cost via fminsearch (Nelder-Mead simplex), starting from [0, 1].

7. Compute warped output coordinates:
   warpedcoords.t1 = pivot_time − wt0 − (1/ws1)·(crop_sc.t2 − crop_sc.t1)/2
   warpedcoords.t2 = pivot_time − wt0 + (1/ws1)·(crop_sc.t2 − crop_sc.t1)/2
   warpedcoords.s1 = crop_sc.s1
   warpedcoords.s2 = crop_sc.s2
```

The output `(s1, t1, s2, t2)` is then written into the ROI table for the slave file, replacing its nominal coordinates. The stored `warpfactor = 1/ws1`.

**Penalty design rationale:**
- The shift penalty uses power 2 (quadratic) — smooth and symmetric.
- The stretch penalty uses power 4 — near-flat near `ws1 = 1`, then steeply rising. This strongly prefers no stretching unless the data clearly requires it, avoiding spurious warps from noise.

---

## 6. Event-Based Alignment

Used when a continuous sync channel is unavailable and instead discrete events (peaks, pulses, triggers) must be matched.

### 6.1 `bml_timealign_annot` — brute-force + fminsearch

Aligns two annotation tables (event lists) by minimizing the sum of mismatches between slave events and their nearest master counterparts.

```matlab
[slave_delta_t, min_cost, warpfactor] = bml_timealign_annot(cfg, master, slave)
```

**Cost function:**
```
cost(delta_t) = sqrt( Σ_i  min(|slave_i + delta_t − nearest_master|, cliptime)² )
```

The `cliptime` cap (default 1 s) prevents outlier events from dominating the optimization.

**Algorithm:**
```
1. Brute-force scan over linspace(-scan, scan, 2·scan/scan_step + 1)
   Find delta_t that minimizes cost.  (default scan = 100 s, scan_step = 0.1 s)

2. Censor unpaired slave events:
   Remove any slave event whose nearest master is farther than censor_mismatch
   (default = scan_step) after the coarse shift.

3. Fine optimization:
   If cfg.timewarp = false:  fminsearch(@costfun1, delta_t)  — 1-D
   If cfg.timewarp = true:   fminsearch(@costfun, [delta_t, warpfactor])  — 2-D
     where costfun applies: aligned_slave = (slave − mean) · warpfactor + mean + delta_t
```

**Key parameters:**

| Parameter | Default | Description |
|---|---|---|
| `cfg.scan` | 100 s | Half-width of brute-force search window |
| `cfg.scan_step` | 0.1 s | Step size for brute-force scan |
| `cfg.censor_mismatch` | = `scan_step` | Remove outlier events beyond this threshold |
| `cfg.cliptime` | 1 s | Cap on individual event mismatch in cost |
| `cfg.timewarp` | false | Allow clock-rate correction |

### 6.2 `bml_sync_match_events` — dynamic programming

Finds the optimal pairing between two sequences of digital events (e.g. trigger pulses on two devices). Used when events may be missing from one side or when the two sequences have different lengths.

```matlab
[idxs_x1, idxs_x2, mean_sim, sim] = bml_sync_match_events(cfg, events1, events2)
```

Each input table must have columns `starts` (event times) and `value` (event amplitude/type).

**Feature representation:**

For each consecutive event triplet `(i, i+1, i+2)` in a sequence, a 5-element feature vector is built:

```
[  Δt_pre,   Δt_post,   value[i],   value[i+1],   starts[i]  ]
   ──────    ────────   ─────────   ──────────────  ─────────
  interval   interval   pre-event   post-event      absolute
  before i   after i+1  value       value           onset time
```

This triplet context makes matching robust to occasional missing events: even if event `i` is absent on one side, the inter-event intervals from its neighbors still identify it.

**Similarity function:**

```
sim(x1_i, x2_j) =
    w_dt_pre  · 1/(1 + (Δt_pre_1  − Δt_pre_2 )²/timetol²)   % timing before
  + w_dt_post · 1/(1 + (Δt_post_1 − Δt_post_2)²/timetol²)   % timing after
  + w_val_pre · [value_pre_1  == value_pre_2 ]                % pre-value match
  + w_val_post· [value_post_1 == value_post_2]                % post-value match
  + w_onset   · 1/(1 + (onset_1  − onset_2 )²/onsettol²)     % absolute onset
```

All weights are normalized to sum to 1. The Lorentzian `1/(1+x²)` kernel gives similarity = 1 when intervals are identical and falls off as differences grow beyond `timetol` (default 1 ms).

**Dynamic programming:**

Maximizes total similarity via the recurrence:

```
dp[i+1, j+1] = max(
    dp[i, j]   + sim(x1[i], x2[j]),   % match i to j
    dp[i+1, j],                         % skip j (event missing in events1)
    dp[i, j+1]                          % skip i (event missing in events2)
)
```

Standard backtracking then recovers the optimal pairing `(idxs_x1, idxs_x2)`.

The DP is analogous to sequence alignment (Smith-Waterman / LCS) but with a continuous similarity score instead of a binary match. The `simtol` parameter allows a small similarity threshold during backtracking to prefer matching over skipping.

---

## 7. High-Level Sync Entry Points

### 7.1 `bml_sync_analog`

The primary synchronization function. Uses a shared analog sync channel present in all recording systems.

```matlab
sync_roi = bml_sync_analog(cfg)
```

**Two-stage pipeline per recording chunk:**

```
Stage 1 — Coarse alignment (envelope method)
   cfg.method = 'envelope', cfg.env_freq = 100 Hz
   cfg.scan   = ±300 s   (wide window for large offsets)
   → slave_delta_t_coarse

Stage 2 — Fine alignment (LPF method)
   cfg.method = 'lpf', cfg.lpf_freq = up to 4000 Hz
   cfg.scan   = ±1 s    (narrow window after coarse correction)
   → slave_delta_t_fine

Optional Stage 3 — Time warp
   bml_timewarp applied after Stage 2
   → warpedcoords  (new s1, t1, s2, t2 for slave file)
```

**Output:** `sync_roi` table — one row per (filetype × chunk), with updated `s1, t1, s2, t2` and `warpfactor`.

**Key parameters:**

| Parameter | Description |
|---|---|
| `cfg.roi` | Input ROI table listing all files with coarse timestamps |
| `cfg.master_filetype` | Which filetype defines the master time axis |
| `cfg.sync_channels` | Table mapping filetype → channel name used for sync |
| `cfg.chunks` | Time segments to process (usually one per session) |
| `cfg.timewarp` | Enable clock-drift correction (default true) |
| `cfg.lpf`, `cfg.lpf_scan` | LPF frequency and scan parameters |
| `cfg.env_scan` | Envelope-method scan parameters |

### 7.2 `bml_sync_audio_event`

Synchronizes Zoom audio files that contain a shared click track or event sequence.

```matlab
sync_roi = bml_sync_audio_event(cfg)
```

1. For each audio file: run `findpeaks()` with `cfg.min_rph` and `cfg.min_ipi` thresholds to detect audio peaks.
2. Build event annotation table from peak locations.
3. Call `bml_timealign_annot()` to match audio peaks to master events.
4. Optionally apply warping (`cfg.timewarp`).
5. Consolidate results across contiguous audio files.

Returns ROI table with `slave_dt`, `warpfactor`, and `alignment_error` per file.

### 7.3 `bml_sync_digital` / `bml_sync_neuroomega_event`

**`bml_sync_digital`:** Generic event-based sync for any digital pulse train.

1. Calls `bml_sync_match_events()` to find optimal event pairing.
2. Groups matched events into chunks by `cfg.sim_threshold` similarity.
3. Fits `master_time = warpfactor · slave_time + delta_t` per chunk.
4. Consolidates chunks with consistent `delta_t` (within `cfg.timetol`).

**`bml_sync_neuroomega_event`:** Specialization for NeuroOmega digital events.

1. Reads events via `bml_read_event()`.
2. Converts to annotation format.
3. Calls `bml_timealign_annot()` with optional warping.
4. Consolidates results within contiguous recording stretches.

---

## 8. Consolidation

`bml_sync_consolidate` takes the raw sync output (possibly many chunks per file) and produces a clean, one-row-per-file ROI table.

```matlab
consolidated = bml_sync_consolidate(cfg)
```

**Two-level process:**

### Level 1 — Per-file consolidation

If a file was synchronized in multiple chunks (e.g. three 10-minute windows across a 30-minute file), there are multiple `(s1, t1, s2, t2)` estimates for the same file. These must be reconciled into a single linear mapping.

```
For each unique file:
  1. Convert all chunk sample ranges to raw (continuous) indices via s2raw().
  2. Fit a line:  t = p(1)·s_raw + p(2)  through all (s, t) reference points.
  3. Check residuals: max|t_predicted − t_observed| ≤ timetol (default 1 ms).
     If residuals > timetol and partial=false → error.
  4. Update t1/t2 of each chunk row to lie on the fitted line.
```

### Level 2 — Contiguous file consolidation

Files of the same `filetype + chantype + Fs` that are temporally adjacent are merged into a single linear mapping.

```
For each (filetype, chantype, Fs) group:
  1. Use bml_annot_consolidate() to detect contiguous file stretches
     (gap < timetol_contiguous, default 1 ms).
  2. For each contiguous stretch:
     a. Fit a single line across all chunks of all files in the stretch.
     b. If max residual ≤ timetol: update all t1/t2 to this global line.
     c. Update warpfactor = 1 / (Fs · p(1)).
     d. Set junction times between adjacent files:
        ends(i) = starts(i+1) = (t2(i) + t1(i+1)) / 2
```

**Why this matters:** The junction time rule ensures that there are no gaps or overlaps in the time coverage of adjacent files. The midpoint between the last reference time of file `i` and the first reference time of file `i+1` becomes the boundary — splitting the uncertainty evenly.

**Key parameters:**

| Parameter | Default | Description |
|---|---|---|
| `cfg.timetol` | 1 ms | Maximum residual for per-file consolidation |
| `cfg.timetol_contiguous` | 1 ms | Gap threshold to detect contiguous files |
| `cfg.contiguous` | true | Enable Level 2 consolidation |
| `cfg.timewarp` | true | Allow linear fit; if false, uses nominal `Fs` |
| `cfg.group` | `'session_id'` | Group variable; files of different groups are never merged |
| `cfg.partial` | false | Allow partial consolidation with warnings instead of errors |

---

## 9. Full Workflow Diagram

```
Raw files on disk
(Trellis, Zoom, NeuroOmega, NSX...)
         │
         │  OS file timestamps → initial ROI table (coarse, unreliable ±seconds)
         ▼
┌─────────────────────────────────────────────────────┐
│               bml_sync_analog()                     │
│  For each recording chunk:                          │
│   1. Load sync channel from master and each slave   │
│   2. bml_timealign (envelope)  → coarse delta_t     │
│   3. bml_timealign (LPF)       → fine delta_t       │
│   4. bml_timewarp              → wt0, ws1           │
│   5. Store new (s1,t1,s2,t2) in sync_roi            │
└────────────────────────┬────────────────────────────┘
                         │  sync_roi: one row per (file × chunk)
                         ▼
┌─────────────────────────────────────────────────────┐
│            bml_sync_consolidate()                   │
│  Level 1: per-file   → fit line through chunks      │
│  Level 2: contiguous → fit line across files        │
│  → one row per file, validated to < 1 ms residual   │
└────────────────────────┬────────────────────────────┘
                         │  consolidated sync_roi
                         ▼
         bml_idx2time() / bml_time2idx()
         All downstream analysis uses synchronized time
```

**For event-based files (audio, digital):**

```
bml_sync_audio_event()
  └─ findpeaks() on audio → event table
  └─ bml_timealign_annot() → delta_t [+ warpfactor]
  └─ bml_sync_consolidate() → one row per audio file

bml_sync_digital()
  └─ bml_sync_match_events() → DP pairing → (idxs1, idxs2)
  └─ linear fit per chunk → delta_t, warpfactor
  └─ bml_sync_consolidate() → one row per digital file
```

---

*Guide written April 2026. Covers BML toolbox as of commit `2599aa2`.*
