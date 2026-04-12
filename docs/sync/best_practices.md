# Best Practices

## Method selection guide

| Signal available | Use this approach | Function |
|-----------------|------------------|----------|
| Shared analog click track (Trellis + Zoom on same cable) | Analog cross-correlation | `bml_sync_analog` |
| Zoom only carries acoustic clicks (no shared cable) | Audio-peak → digital TTL match | `bml_sync_audio_event` |
| NeuroOmega TTL pulses | Event matching | `bml_sync_neuroomega_event` |
| Psychtoolbox task events (via photodiode / audio) | DP match + linear warp fallback | `bml_sync_digital` + `polyfit` |

When in doubt, prefer analog sync (`bml_sync_analog`) over event sync — it uses the full waveform shape and is more robust to missing pulses.

## Chunking strategy

```matlab
% Recommended: 60–100 s windows
chunks = bml_chunk_sessions(session, [], 80);

% Short sessions (< 5 min): use 2–3 chunks
chunks = bml_chunk_sessions(session, 3);

% Very long sessions (> 2 hr): use fixed 90 s windows
chunks = bml_chunk_sessions(session, [], 90);
```

**Why chunk?** A single `delta_t` over a 3-hour session may mask local drift. Shorter windows give one estimate per drift epoch, and `bml_sync_consolidate` then fits the best global line.

**Don't go below 30 s** — the envelope cross-correlation becomes noise-dominated.

## Always validate residuals

```matlab
% After consolidation
max_err_ms = max(abs(sync_roi_final.meanerror)) * 1000;
fprintf('Max residual: %.3f ms\n', max_err_ms);

if max_err_ms > 1
    warning('Residual > 1 ms — inspect per-file diagnostics');
end
```

Target: **< 1 ms** residual for neural data. For behavior-only data, < 5 ms is usually acceptable.

## Use `bml_sync_check`

```matlab
bml_sync_check(sync_roi_final);
```

This prints a per-device, per-session summary table showing `delta_t`, `warpfactor`, and `meanerror`. It warns when:
- `warpfactor` deviates > 50 ppm from 1.0 (suspicious clock drift)
- Any file is missing a sync entry
- Residual exceeds `timetol`

## BIDS conventions

All time-stamped output files use the `-sync.tsv` suffix and store times in **master-clock seconds**:

```
sub-DM1001_ses-intraop_task-speech_events-sync.tsv   ← starts in master time
sub-DM1001_ses-intraop_sync_roi.tsv                  ← sync coordinate pairs
```

Never store slave-clock times in analysis files. Downstream code should never need to apply a `delta_t` manually.

## Coordinate system reminders

- `t1`, `t2` are **master-clock seconds** (Ripple/Trellis wall time)
- `s1`, `s2` are **sample indices** (1-based, edge of first/last sample)
- Times returned by `bml_idx2time` are **sample midpoints**: $t = (s - 0.5) / F_s + \text{offset}$

```matlab
% Convert sample index to master time
t_master = bml_idx2time(sync_roi, sample_idx);

% Convert master time to sample index
s = bml_time2idx(sync_roi, t_master);
```

## Re-running sync

Sync should be re-run if:
- Raw files are re-preprocessed (e.g., resampled at a different rate)
- A new recording device is added to the pipeline
- Residuals from a previous run exceeded tolerance

Keep the `sync_roi_final.mat` together with the raw data, version-controlled in the session folder.

## Python migration roadmap

BML is currently MATLAB-only, but the core ideas map cleanly to Python:

| MATLAB | Python equivalent |
|--------|------------------|
| Annotation table (MATLAB `table`) | `pandas.DataFrame` with `starts`, `ends` columns |
| `bml_annot_intersect` | `pandas.IntervalIndex` merge or `pyranges` |
| `bml_timealign` | `scipy.signal.correlate` |
| `bml_timewarp` | `scipy.optimize.minimize` with Nelder-Mead |
| `bml_sync_match_events` | DP in pure Python or `numba` |
| `bml_read_event` / FT data | `neo` (Python-Neo) |
| `bml_annot_describe` | `pandas.groupby(...).agg(...)` |

The recommended migration order:
1. **I/O layer** — port `bml_roi_table`, `bml_annot_read_tsv`, `bml_annot_write_tsv`
2. **Interval algebra** — port the set operations (filter, intersect, union, difference)
3. **Sync pipeline** — port `bml_timealign` and `bml_sync_match_events`
4. **Feature extraction** — port `bml_annot_calculate`

A Python port is most valuable for post-sync analysis (steps 1 + 4). The sync pipeline itself (steps 2 + 3) can remain in MATLAB longer since it is run once per session.
