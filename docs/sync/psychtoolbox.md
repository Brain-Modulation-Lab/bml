# Task Laptop Synchronization (Psychtoolbox)

The task laptop runs Psychtoolbox and logs stimulus onset times using its own system clock. This clock can be **hours offset** from Ripple master time (the OS timestamp is independent of the neural recording system). The drift, however, is low once synchronized.

## Two-stage strategy

```{mermaid}
flowchart TD
    A[task_events\nPsychtoolbox times] --> B[bml_sync_match_events\nDP matching]
    C[master_events\nRipple TTL times] --> B
    B --> D{Matched?}
    D -->|Yes| E[Exact Ripple timestamp\nfor matched events]
    D -->|No / gap| F[Linear warp interpolation\npolyfit on matched block]
    E --> G[task_events_synced]
    F --> G
    G --> H[bml_annot_write_tsv\n*-sync.tsv]
```

### Stage 1 — DP matching

`bml_sync_match_events` finds which task events correspond to which Ripple TTL pulses. The match uses pre/post inter-event intervals and event values (e.g., stimulus type codes).

### Stage 2 — Hybrid time assignment

For matched events: use the **exact Ripple timestamp** (zero residual).
For unmatched events (gaps, missing pulses): use **linear warp** — `polyfit` on the longest contiguous matched block, then interpolate.

```matlab
% Load task events from Psychtoolbox log
task_events = bml_annot_read_tsv('sub-DM1001_task-speech_events.tsv');

% Load master events from Ripple digital channel
master_events = bml_read_event(trellis_roi);
master_events = bml_event2annot([], master_events);
master_events = master_events(master_events.value == 1, :);

% --- STAGE 1: DP matching ---
cfg = [];
cfg.timetol   = 0.001;  % 1 ms ITI tolerance
cfg.onsettol  = 100;    % allow up to 100 s initial offset
[idxs_master, idxs_task, mean_sim, sim] = ...
    bml_sync_match_events(cfg, master_events, task_events);

fprintf('Matched %d / %d task events (mean sim = %.3f)\n', ...
    length(idxs_task), height(task_events), mean_sim);

% --- STAGE 2: linear warp for all events ---
% Fit a line: master_time = a * task_time + b
tbar = mean(task_events.starts(idxs_task));
p = polyfit(task_events.starts(idxs_task) - tbar, ...
            master_events.starts(idxs_master), 1);
task_events.starts_corrected = p(1) * (task_events.starts - tbar) + p(2);

% --- PRIMARY: substitute exact Ripple time for matched events ---
task_events.starts_synced = task_events.starts_corrected;
task_events.starts_synced(idxs_task) = master_events.starts(idxs_master);

% Save synced events
bml_annot_write_tsv(task_events, 'sub-DM1001_task-speech_events-sync.tsv');
```

## Why the fallback matters

A task event may not have a corresponding Ripple TTL if:
- The stimulus was delivered silently (no photodiode / no audio trigger)
- The event occurred outside the Ripple recording window
- The TTL cable was momentarily disconnected

For those events, the linear warp gives sub-millisecond accuracy if the clock drift is stable (typically < 5 ppm for modern laptops).

## Residual validation

```matlab
% Check how well matched events align after synchronization
residuals = task_events.starts_synced(idxs_task) - master_events.starts(idxs_master);
fprintf('Residual: mean=%.4f ms, max=%.4f ms\n', ...
    mean(abs(residuals))*1000, max(abs(residuals))*1000);

% Acceptable: mean < 1 ms, max < 5 ms
assert(max(abs(residuals)) < 0.005, ...
    'Sync residual exceeds 5 ms — inspect diagnostic plot');
```

## Output file convention

Synced events are written to a BIDS-compatible TSV with the `-sync` suffix:

```
sub-DM1001_ses-intraop_task-speech_events.tsv       ← original Psychtoolbox times
sub-DM1001_ses-intraop_task-speech_events-sync.tsv  ← Ripple master-clock times
```

The `-sync.tsv` file is what all downstream analysis loads.

## Parameters for `bml_sync_digital`

When syncing via `bml_sync_digital` (which calls `bml_sync_match_events` internally):

| Parameter | Default | Notes |
|-----------|---------|-------|
| `timetol` | `1e-3` | ITI matching tolerance (1 ms) |
| `sim_threshold` | `0.9` | Minimum similarity to count as a matched region |
| `diagnostic_plot` | `false` | Show similarity + residual plot |
| `plot_title` | `'events diagnostic plot'` | Figure title |

:::{warning}
`bml_sync_digital` errors if more than 10 contiguous matched chunks are detected — this usually indicates poor alignment. Inspect the diagnostic plot and check that master and slave event streams actually overlap in time.
:::
