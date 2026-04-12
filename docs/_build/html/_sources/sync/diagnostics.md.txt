# Diagnostic Plots

Every sync function produces a diagnostic figure when `cfg.diagnostic_plot = true` (or `cfg.plot_diagnostic = true` for consolidation). This page explains what each plot shows, how to read it, and what good vs. bad output looks like.

---

## 1. `bml_sync_match_events` — DP similarity plot

**How to enable**:
```matlab
cfg.diagnostic_plot = true;
[idxs_m, idxs_s, mean_sim, sim] = bml_sync_match_events(cfg, master_events, slave_events);
```

**What you see**: a 2-panel figure.

```
┌─────────────────────────────────────────┐
│ Panel 1: Similarity vector              │
│                                         │
│  1.0 ┤ ████████████████████████        │
│  0.5 ┤          ░░░░░░░░               │
│  0.0 ┤                                 │
│       └──────────────────────────────  │
│            event index (matched pairs) │
├─────────────────────────────────────────┤
│ Panel 2: DP matrix + backtrack path     │
│                                         │
│  master │░░░░░░░░░░░░                  │
│  index  │    ░░░░░░░░░░░░░░            │
│         │            ░░░░░░░░░░░░░░░   │
│          └─────────────────────────    │
│                  slave index           │
└─────────────────────────────────────────┘
```

**Panel 1 — similarity vector**

Each point is one matched pair. The y-axis is similarity (0–1).

| Pattern | Meaning |
|---------|---------|
| All points near 1.0 | Perfect match — event patterns are identical |
| A cluster of high values, then a drop | One contiguous well-matched block; events outside are noise |
| Low values throughout (< 0.5) | Poor match — wrong scan range, wrong event type, or no overlap |
| Alternating high/low | Possible duplicate event structure in one recording |

**Panel 2 — DP matrix**

The matrix `dp[i,j]` = best total similarity achievable by matching the first `i` master events to the first `j` slave events. The overlaid line is the backtrack path — the actual pairing chosen.

| Pattern | Meaning |
|---------|---------|
| Path is a smooth diagonal | Clean 1:1 correspondence, events align well |
| Path has horizontal or vertical runs | Events missing on one side — the path skips over them |
| Path jumps diagonally and then stalls | One device has extra events not present in the other |
| Path stays in one corner | No real overlap — scan range too narrow, or wrong files |

---

## 2. `bml_sync_audio_event` / `bml_sync_neuroomega_event` — event alignment plot

**How to enable**:
```matlab
cfg.diagnostic_plot = true;
sync_roi = bml_sync_audio_event(cfg);       % or bml_sync_neuroomega_event
```

**What you see**: one 2-panel figure **per file** in `cfg.roi`.

```
┌───────────────────────────────┬──────────────────────────┐
│ Panel 1: Event timeline       │ Panel 2: Residual         │
│                               │ histogram                 │
│  ●  ●  ●  ●  ●  ●  ●  ●  ●  │                           │
│  master events (blue ●)       │  ██                       │
│                               │  ████                     │
│  *  *  *  *  *  *  *  *  *  │  ████████                  │
│  slave events corrected (★)  │  ██████████               │
│                               │  ████                     │
│ ────────────────────────────  │  ██                       │
│      master time (s)          │  -4  -3  -2  -1   0       │
│                               │  log10 |Δt| (s)           │
└───────────────────────────────┴──────────────────────────┘
```

**Panel 1 — timeline**

Blue circles = master event times. Red stars = slave event times **after** applying `delta_t` (and `warpfactor` if enabled).

| Pattern | Meaning |
|---------|---------|
| Circles and stars perfectly interleaved | Excellent alignment |
| Stars consistently offset from circles | `delta_t` estimate is slightly off — check scan range |
| Stars spread out relative to circles | Residual drift — consider enabling `timewarp = true` |
| Many extra stars with no nearby circle | False peaks detected — increase `min_rph` threshold |
| Many circles with no nearby star | Events missed — decrease `min_rph` or check audio quality |

**Panel 2 — residual histogram**

X-axis is $\log_{10}|\Delta t|$ (seconds). Each bar is a matched event pair.

| Pattern | Meaning |
|---------|---------|
| Sharp peak at −3 or lower (< 1 ms) | Excellent — events agree at sub-millisecond level |
| Peak at −2 (10 ms) | Acceptable for behavior; marginal for neural data |
| Peak at −1 (100 ms) or higher | Poor alignment — inspect timeline |
| Bimodal histogram | Two populations: matched and unmatched events mixed together |

---

## 3. `bml_sync_digital` — residual and alignment plot

**How to enable**:
```matlab
cfg.diagnostic_plot = true;
sync_roi = bml_sync_digital(cfg, master_events, slave_events);
```

**What you see**: one 3-panel figure **per contiguous matched chunk**.

```
┌────────────────────────────────────────────────────────┐
│ Panel 1: Residual over time                            │
│                                                        │
│   0.002 ┤ ·  ·  ·  · ·  ··  ·  (all matched, black)  │
│   0.000 ┼────────────────── 0                         │
│  -0.002 ┤   ●●●●●●●●●●●●●●● (chunk events, red)      │
│          └────────────────────────────────             │
│               master event time (s)                    │
├────────────────────────────────────────────────────────┤
│ Panel 2: Timeline (after correction)                   │
│                                                        │
│  ● ● ● ● ● ● ● ● ● ● ● ● master (blue ●)             │
│  * * * * * * * * * * * * slave corrected (red ★)      │
│  ──────────────────────────────────────────            │
│           master time (s)                              │
├────────────────────────────────────────────────────────┤
│ Panel 3: Residual histogram                            │
│                                                        │
│  ████████████                                          │
│  ██████████████████                                    │
│  -4    -3    -2    -1    0                             │
│  log10 |master − slave| (s)                            │
└────────────────────────────────────────────────────────┘
```

**Panel 1 — residual over time**

Y-axis: `slave.starts - master.starts` for each matched pair. Red points = events used for this chunk's `polyfit`; black = all matched pairs.

| Pattern | Meaning |
|---------|---------|
| Flat horizontal band near 0 | Pure offset, no drift — good |
| Tilted straight line | Linear drift — enable `timewarp = true` |
| Curved or scattered | Non-linear drift or bad matching — inspect DP plot |
| Sudden jump | Two separate sessions mixed; check `cfg.group` |
| Red points track the line, black scatter around it | Normal — chunk is a well-matched contiguous segment |

**Panel 2 and 3** — same interpretation as the audio/NeuroOmega plots above.

---

## 4. `bml_sync_consolidate` — pairwise residual heatmap

**How to enable**:
```matlab
cfg.plot_diagnostic = true;
sync_roi_final = bml_sync_consolidate(cfg);
```

**What you see**: one heatmap **per file** (Level 1) and one per contiguous file group (Level 2). Axes are chunk IDs; color is the pairwise `delta_t` disagreement.

```
           chunk ID
        1    2    3    4
      ┌────┬────┬────┬────┐
   1  │  0 │0.0 │0.0 │0.0 │  ← all near zero = consistent
      ├────┼────┼────┼────┤
   2  │0.0 │  0 │0.0 │0.0 │
      ├────┼────┼────┼────┤
   3  │0.0 │0.0 │  0 │2.5 │  ← chunk 3–4 disagree → rogue chunk
      ├────┼────┼────┼────┤
   4  │0.0 │0.0 │2.5 │  0 │
      └────┴────┴────┴────┘
  (color = |delta_t difference| in seconds)
```

| Pattern | Meaning |
|---------|---------|
| All cells near zero (dark) | All chunks agree — consolidation will succeed |
| One row/column bright | That chunk is a rogue — its estimate disagrees with all others |
| Checkerboard pattern | Alternating-sign drift; try shorter chunk windows |
| All cells bright | No two chunks agree — sync failed entirely |

**What to do with a rogue chunk**: find the outlier row/column, remove that chunk from `cfg.roi`, and re-run consolidation.

```matlab
% Identify rogue by inspecting sync_roi before consolidation
sync_roi(sync_roi.meanerror > 0.005, :)  % > 5 ms residual

% Remove it
sync_roi_clean = sync_roi(sync_roi.meanerror <= 0.005, :);
sync_roi_final = bml_sync_consolidate(struct('roi', sync_roi_clean));
```

---

## Summary: what to check first

| Question | Plot to look at | Panel |
|----------|----------------|-------|
| Did DP find the right event pairs? | `bml_sync_match_events` | DP matrix path |
| Are residuals < 1 ms? | Any function | Residual histogram |
| Is there drift? | `bml_sync_digital` | Residual-over-time (tilted line?) |
| Is one chunk an outlier? | `bml_sync_consolidate` | Pairwise heatmap |
| Are all events accounted for? | Audio/NeuroOmega | Timeline (circle/star ratio) |
| Is the similarity high enough? | `bml_sync_match_events` | Similarity vector |
