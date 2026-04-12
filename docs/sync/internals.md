# Alignment Function Internals

This page explains the low-level alignment functions — what each one does, how they relate to each other, and when to call them directly.

## Full call graph

```{mermaid}
flowchart TD

  subgraph top["High-level (you call these)"]
    SA[bml_sync_analog]
    SN[bml_sync_neuroomega_event]
    SAE[bml_sync_audio_event]
    SD[bml_sync_digital]
  end

  subgraph mid["Mid-level"]
    TW[bml_timewarp]
    TAA[bml_timealign_annot]
    SME[bml_sync_match_events]
  end

  subgraph low["Low-level"]
    TA[bml_timealign]
    PF[polyfit]
  end

  SA -->|"envelope pass ±300s\nthen LPF pass ±1s"| TW
  TW -->|"coarse offset\nvia xcorr"| TA
  TW -->|"fine offset + drift\nNelder-Mead"| TW

  SN --> TAA
  SAE --> TAA
  TAA -->|"grid search\n+ fminsearch"| TAA

  SD --> SME
  SME -->|"DP pairing"| SME
  SD -->|"polyfit on\nmatched pairs"| PF
```

---

## The two dimensions

There are two independent choices when aligning two recordings:

| | **Waveform input** | **Event list input** |
|---|---|---|
| **Offset only** | `bml_timealign` | `bml_timealign_annot` |
| **Offset + drift** | `bml_timewarp` | `bml_timewarp_annot` |

- **Waveform** = continuous FT raw signal (e.g. analog click track recorded by both devices)
- **Event list** = annotation table of timestamps (e.g. TTL pulses, audio peaks)
- **Offset** = constant time shift $\delta t$
- **Drift** = linear clock rate difference $ws_1 \neq 1$

---

## What each function does

### `bml_timealign` — xcorr on waveforms

Input: two `FT_DATATYPE_RAW` signals.

1. Resample both to `resample_freq` (default 10 kHz)
2. Preprocess: **envelope** (abs of Hilbert → 100 Hz lowpass) or **LPF** (Butterworth)
3. Normalize: subtract robust median, divide by robust std
4. `xcorr(..., 'coeff')` → find peak lag → `slave_delta_t`

```matlab
[delta_t, max_corr] = bml_timealign(cfg, master_raw, slave_raw);
```

**Never called directly in normal use** — only called inside `bml_timewarp`.

---

### `bml_timewarp` — xcorr + Nelder-Mead on waveforms

Input: two `FT_DATATYPE_RAW` signals.

1. Calls `bml_timealign` → coarse offset
2. Crops both signals to their overlap region; sets `pivot_time = midpoint`
3. Builds interpolation function `f(t)` from slave
4. Minimizes cost with `fminsearch` over `[wt0, ws1]`:

$$w(t) = t_{\text{pivot}} + wt_0 + (t - t_{\text{pivot}}) \cdot ws_1$$

$$\mathcal{L}(wt_0, ws_1) = -\frac{\langle f(w(\mathbf{t})), p \rangle}{\|f(w(\mathbf{t}_0))\| \|p\|} + \left(\frac{wt_0}{P_{\delta t}}\right)^2 + \left(\frac{ws_1 - 1}{P_\xi}\right)^4$$

5. Converts fitted `wt0`, `ws1` back to `(s1, t1, s2, t2)` coordinates:

$$t_1^{\text{new}} = t_{\text{pivot}} - wt_0 - \frac{t_2^{\text{crop}} - t_1^{\text{crop}}}{2 \cdot ws_1}, \quad t_2^{\text{new}} = t_{\text{pivot}} - wt_0 + \frac{t_2^{\text{crop}} - t_1^{\text{crop}}}{2 \cdot ws_1}$$

```matlab
wc = bml_timewarp(cfg, master_raw, slave_raw);
% wc.s1, wc.t1, wc.s2, wc.t2  ← sync coordinates
% wc.wt0, wc.ws1               ← fitted parameters
```

**Called by**: `bml_sync_analog` (twice per chunk: envelope pass then LPF pass).

:::{note}
The denominator `dot0` is fixed at the **initial** unwarped slave — it does not change during optimization. This stabilizes the cost landscape and prevents the trivial solution $ws_1 \to 0$.
:::

---

### `bml_timealign_annot` — grid search on event lists

Input: two annotation tables (event timestamps).

1. Brute-force scan over `[-scan, +scan]` with step `scan_step`; at each shift, compute sum of squared nearest-neighbor distances
2. Censor slave events with no close master match (> `censor_mismatch`)
3. `fminsearch` to refine `delta_t` (and optionally `warpfactor`)

Cost function (no drift):
$$\mathcal{L}(\delta t) = \sqrt{\sum_i \min\!\left(\min_j |s_i + \delta t - m_j|,\; \text{cliptime}\right)^2}$$

```matlab
[delta_t, cost, warpfactor] = bml_timealign_annot(cfg, master_events, slave_events);
```

**Called by**: `bml_sync_neuroomega_event`, `bml_sync_audio_event`.

---

### `bml_timewarp_annot` — alias for `bml_timealign_annot` with drift

```matlab
function [delta_t, cost, warpfactor] = bml_timewarp_annot(cfg, master, slave)
  cfg.timewarp = true;
  [delta_t, cost, warpfactor] = bml_timealign_annot(cfg, master, slave);
end
```

Exists for convenience. **Not called** by any pipeline function — all callers use `bml_timealign_annot` directly.

---

### `bml_sync_match_events` — DP pairing

Input: two annotation tables.

Does **not** estimate a time offset. Only answers: which event in slave corresponds to which event in master?

Uses a 5-feature similarity vector and LCS-style dynamic programming. See [DP Event Matching](dp_matching.md) for full details.

**Called by**: `bml_sync_digital` only.

---

## Decision guide: which function to use?

```{mermaid}
flowchart TD
    A{What do you have?} -->|continuous waveform| B{Need drift correction?}
    A -->|event timestamps| C{Are sequences complete\nand in the same order?}

    B -->|No| D[bml_timealign\nxcorr offset]
    B -->|Yes| E[bml_timewarp\nxcorr + Nelder-Mead]

    C -->|Yes — same hardware signal| F[bml_timealign_annot\ngrid search offset]
    C -->|No — could be missing/ambiguous| G[bml_sync_match_events\nDP pairing\nthen polyfit]

    E -->|called inside| SA[bml_sync_analog]
    F -->|called inside| SN[bml_sync_neuroomega_event\nbml_sync_audio_event]
    G -->|called inside| SD[bml_sync_digital]
```

| Situation | Function to call |
|-----------|----------------|
| Analog click track, Zoom ↔ Ripple | `bml_sync_analog` |
| Audio peaks, Zoom ↔ Ripple (no shared cable) | `bml_sync_audio_event` |
| TTL pulses, NeuroOmega ↔ Ripple | `bml_sync_neuroomega_event` |
| Task events, Psychtoolbox ↔ Ripple | `bml_sync_digital` |
| Custom: waveform alignment only | `bml_timewarp` |
| Custom: event alignment, known to be complete | `bml_timealign_annot` |
| Custom: event alignment, sequences may differ | `bml_sync_match_events` + `polyfit` |
| Debugging: what offset did we find? | Call any of the above with `diagnostic_plot = true` |
