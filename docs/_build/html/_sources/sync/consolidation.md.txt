# Consolidation

After per-chunk synchronization, each file typically has **multiple rows** in the `sync_roi` table — one per time window (chunk). `bml_sync_consolidate` merges these into **one row per file** and optionally merges time-contiguous files of the same type.

## Why consolidation is needed

Chunking improves noise robustness: short windows catch local drift changes. But analysis tools need a single `(s1, t1, s2, t2)` coordinate pair per file. Consolidation solves:

$$\min_{t_0, \xi} \sum_{k} \left( t_k^{\text{master}} - \bigl(t_0 + \xi \cdot s_k\bigr) \right)^2$$

where $(s_k, t_k^{\text{master}})$ are the anchor points from each chunk.

## Two-level consolidation

| Level | What it does | When triggered |
|-------|-------------|----------------|
| **Level 1** | Merge chunks → 1 row per file | Always |
| **Level 2** | Merge contiguous files of same type | `cfg.contiguous = true` (default) |

Level 2 finds files from the same filetype that end where the next begins (within `timetol_contiguous`), then fits a single affine map across all of them.

## Usage

```matlab
cfg = [];
cfg.roi              = [sync_roi_analog; sync_roi_ao; sync_roi_task];
cfg.timetol          = 1e-3;    % 1 ms residual tolerance
cfg.contiguous       = true;    % merge adjacent files of same type
cfg.timetol_contiguous = 1e-3;
cfg.timewarp         = true;    % allow linear drift correction
cfg.group            = 'session_id';  % don't mix sessions
cfg.plot_diagnostic  = false;   % pairwise residual matrix

sync_roi_final = bml_sync_consolidate(cfg);

% Check residuals
fprintf('Max residual: %.4f ms\n', ...
    max(abs(sync_roi_final.meanerror)) * 1000);
```

## Parameters

| Parameter | Default | Meaning |
|-----------|---------|---------|
| `timetol` | `1e-3` | Max allowed residual per file (s) |
| `timetol_contiguous` | `1e-3` | Gap < this → treat files as contiguous |
| `contiguous` | `true` | Enable Level 2 merge |
| `timewarp` | `true` | Fit slope as well as offset |
| `group` | `'session_id'` | Column that separates independent sessions |
| `partial` | `false` | Allow partial consolidation (some files fail) |
| `rowisfile` | `true` | Assume one physical file per row |
| `plot_diagnostic` | `false` | Show pairwise residual heatmap |

## Diagnostic plot

`cfg.plot_diagnostic = true` generates an $N \times N$ matrix of pairwise residuals between all file-pairs in a session. A file with systematically large residuals against all others is a rogue chunk (bad sync estimate). Remove it and re-consolidate.

## What the output looks like

```matlab
sync_roi_final

% id  starts  ends  folder  name  filetype  chantype  s1  t1  s2  t2  ...
%  1  52310   52610  /data  sub-DM1001_trellis.nev  trellis  nev  1  52310  ...
%  2  52310   52610  /data  sub-DM1001_ao.mat  neuroomega  raw  1  NaN+52310  ...
```

Each row has one affine coordinate pair that maps every sample in that file to master-clock time.

## Saving

```matlab
save(fullfile(PATH_SYNC, 'sync_roi_final.mat'), 'sync_roi_final');
% Or as TSV for BIDS compatibility:
bml_annot_write_tsv(sync_roi_final, fullfile(PATH_SYNC, 'sync_roi_final.tsv'));
```

## Validation checklist

```matlab
% 1. All files have a sync entry
assert(height(sync_roi_final) == expected_n_files, 'Missing files in sync_roi');

% 2. No NaN delta_t
assert(~any(isnan(sync_roi_final.delta_t)), 'NaN delta_t found — check raw sync');

% 3. Residuals under 1 ms
assert(max(abs(sync_roi_final.meanerror)) < 1e-3, 'Residual > 1 ms');

% 4. Warpfactors are reasonable (< 50 ppm drift)
assert(all(abs(sync_roi_final.warpfactor - 1) < 50e-6), 'Excessive drift');
```

## Common failures

**`timetol` violated** — Two chunks from the same file disagree by more than 1 ms. Inspect the diagnostic plot to find the outlier chunk. Common causes: low signal in one chunk, recording gap.

**Contiguous merge fails** — Files detected as contiguous but their sync estimates diverge. Reduce `cfg.contiguous = false` to skip Level 2 and consolidate each file independently.

**Missing `session_id`** — If `roi` doesn't have a `session_id` column, pass `cfg.group = []` to consolidate all rows together.
