# NeuroOmega Synchronization

The Alpha Omega NeuroOmega (AO) system is an intraoperative recording system used in parallel with Ripple/Trellis. Both systems listen to the same TTL pulse train; BML finds `delta_t` and (optionally) `warpfactor` by matching those shared digital event sequences.

## How it works

```{mermaid}
flowchart LR
    A[Trellis digital events\nmaster TTL pulses] -->|bml_timealign_annot| C[bml_sync_neuroomega_event]
    B[NeuroOmega events\nread from .mat / .nev] -->|bml_read_event| C
    C --> D[slave_delta_t\nwarpfactor per file]
    D --> E[sync_roi_neuroomega]
```

The key function is `bml_sync_neuroomega_event`. For each file in `cfg.roi`:

1. Read NeuroOmega events with `bml_read_event` → convert to annotation table
2. Select master events near the current file's time window (±`coarsetol` seconds)
3. Call `bml_timealign_annot` to find `slave_delta_t` and `warpfactor` via DP-based event matching

## Usage

```matlab
% 1 — Load master events from Ripple
master_events = bml_read_event(trellis_roi);
master_events = bml_event2annot([], master_events);
master_events = master_events(master_events.value == 1, :);  % TTL rising edges only

% 2 — Synchronize NeuroOmega files
cfg = [];
cfg.roi             = roi(strcmp(roi.filetype,'neuroomega'), :);
cfg.master_events   = master_events;
cfg.scan            = 100;     % coarse scan ±100 s
cfg.scan_step       = 0.1;
cfg.timewarp        = false;   % AO clocks are stable; offset-only is usually enough
cfg.timetol         = 1e-6;    % residual tolerance after alignment
cfg.min_events      = 10;      % skip files with <10 events
cfg.diagnostic_plot = true;

sync_roi_ao = bml_sync_neuroomega_event(cfg);
```

## Key parameters

| Parameter | Default | Meaning |
|-----------|---------|---------|
| `scan` | 100 | Coarse scan range in seconds |
| `scan_step` | 0.1 | Step size for initial grid search |
| `timewarp` | `false` | Enable linear drift correction |
| `timetol` | `1e-6` | Max acceptable residual (s) |
| `coarsetol` | 100 | Expand master event window by this many seconds |
| `min_events` | 10 | Files with fewer events → `NaN` delta_t |
| `strict` | `false` | Error (vs. warning) when `timetol` violated |
| `restrict_master_by` | — | Column name to group master events (e.g. `session_id`) |

## The `restrict_master_by` option

When a single NeuroOmega `.mat` file spans **more than one Trellis file**, master events from different sessions get mixed. Setting `cfg.restrict_master_by = 'session_id'` tells the aligner to keep only the dominant session's events, censoring the minority group before alignment.

```matlab
cfg.restrict_master_by = 'session_id';
```

## Diagnostic plot

`cfg.diagnostic_plot = true` produces a scatter of master vs. slave event times with the fitted line superimposed. Good alignment produces a straight line with residuals under 1 ms.

## Output columns added to sync_roi

| Column | Description |
|--------|-------------|
| `delta_t` | Slave offset relative to master (seconds) |
| `warpfactor` | Slope correction (1.0 = no drift) |
| `sync_channel` | `'digital'` |
| `meanerror` | Mean absolute residual after alignment |

## Common issues

**Too few events** — Files during idle periods may have < 10 TTL events. These are skipped (`delta_t = NaN`). Pass `cfg.min_events = 5` to lower the threshold, but inspect results carefully.

**Multiple AO files per session** — Each `.mat` file gets its own row. After `bml_sync_neuroomega_event`, call `bml_sync_consolidate` to merge chunks into one row per physical file.

**Large coarse offset** — AO clocks can drift by tens of seconds if the recording was started much later. Increase `cfg.scan` (e.g., `300`) to widen the initial search window.
