# DP Event Matching

`bml_sync_match_events` solves the core problem of aligning two asynchronous event sequences: given a master list of TTL pulses and a slave list, find the best monotone correspondence even when events are missing from one side or duplicated.

## Problem statement

Two sequences of events:

- **Master** $\mathbf{m} = (m_1, \ldots, m_N)$ — Ripple TTL timestamps + values
- **Slave** $\mathbf{s} = (s_1, \ldots, s_M)$ — device timestamps + values

Goal: find index vectors $\mathbf{i} \subseteq \{1..N\}$ and $\mathbf{j} \subseteq \{1..M\}$ (same length, strictly increasing) that maximize total similarity while preserving order.

## Feature vector

Each event $k$ is represented by a 5-element feature vector:

$$\mathbf{x}_k = \bigl[\underbrace{\Delta t_k^{\text{pre}}}_{\text{pre-ITI}},\; \underbrace{\Delta t_k^{\text{post}}}_{\text{post-ITI}},\; \underbrace{v_{k-1}}_{\text{pre-value}},\; \underbrace{v_k}_{\text{post-value}},\; \underbrace{t_k}_{\text{onset}}\bigr]$$

where $\Delta t_k^{\text{pre}} = t_k - t_{k-1}$ and $\Delta t_k^{\text{post}} = t_{k+1} - t_k$.

## Similarity function

$$\text{sim}(\mathbf{x}, \mathbf{y}) = w_1 \cdot L\!\left(\frac{x_1 - y_1}{\tau}\right) + w_2 \cdot L\!\left(\frac{x_2 - y_2}{\tau}\right) + w_3 \cdot \mathbf{1}[x_3 = y_3] + w_4 \cdot \mathbf{1}[x_4 = y_4] + w_5 \cdot L\!\left(\frac{x_5 - y_5}{\tau_\text{onset}}\right)$$

where $L(u) = \frac{1}{1+u^2}$ is the **Lorentzian** kernel, $\tau$ = `timetol` (default 1 ms), and $\tau_\text{onset}$ = `onsettol` (default 100 s).

By default $w_5 = 0$ (onset not used), so the weights are $w_1 = w_2 = w_3 = w_4 = 1/4$.

## Dynamic programming

The DP table is filled as a longest-common-subsequence variant:

$$\text{dp}[i+1, j+1] = \max\!\bigl(\text{dp}[i,j] + \text{sim}(\mathbf{x}_i, \mathbf{y}_j),\;\; \text{dp}[i+1,j],\;\; \text{dp}[i,j+1]\bigr)$$

Backtracking then recovers the matched index pairs.

## Usage

```matlab
cfg = [];
cfg.timetol         = 0.001;   % 1 ms Lorentzian half-width
cfg.onsettol        = 100;     % 100 s onset tolerance
cfg.weight_time_pre  = 1/4;
cfg.weight_time_post = 1/4;
cfg.weight_value_pre = 1/4;
cfg.weight_value_post = 1/4;
cfg.weight_onset     = 0;      % onset term off by default
cfg.simtol           = 0;      % accept all pairs with sim > 0
cfg.diagnostic_plot  = false;

[idxs_master, idxs_slave, mean_sim, sim] = ...
    bml_sync_match_events(cfg, master_events, slave_events);
```

## Outputs

| Output | Description |
|--------|-------------|
| `idxs_master` | Indices into `master_events` |
| `idxs_slave` | Indices into `slave_events` |
| `mean_sim` | Average per-pair similarity (0–1) |
| `sim` | Per-pair similarity vector |

## How `bml_sync_digital` uses the match

After matching, `bml_sync_digital` groups matched pairs into **contiguous chunks** using `bml_annot_detect` on the similarity signal. Each chunk gets a per-chunk `polyfit` to estimate `delta_t` and drift. Chunks are then consolidated if their `delta_t` estimates agree within `timetol`.

```{mermaid}
flowchart TD
    A[master_events\nslave_events] --> B[bml_sync_match_events\nDP similarity]
    B --> C[sim vector]
    C --> D[bml_annot_detect\nthreshold=0.9]
    D --> E[contiguous chunks\nof matched events]
    E --> F[polyfit per chunk\ndelta_t, warp]
    F --> G[bml_annot_consolidate\nmerge compatible chunks]
    G --> H[sync_roi rows]
```

## Tuning the similarity threshold

`bml_sync_digital` uses `sim_threshold = 0.9` by default to detect good-match regions. If the algorithm produces too many chunks:
- Increase `sim_threshold` toward 1.0 (stricter)
- Reduce `timetol` for tighter timing agreement

If the algorithm fails to find any matching region:
- Widen `scan` in `bml_timealign_annot`
- Lower `sim_threshold`
- Check that both event streams actually overlap in time

## Version history

| Version | Features used | Notes |
|---------|--------------|-------|
| Current (`bml_sync_match_events`) | 5: pre-ITI, post-ITI, pre-value, post-value, onset | `weight_onset` defaults to 0 (onset off) |
| Archived (`bml_sync_match_events2`) | 4: pre-ITI, post-ITI, pre-value, post-value | No onset term |

The onset term (`weight_onset > 0`) is useful when the same event pattern repeats multiple times in a session (e.g., repeated block structure). Setting `cfg.weight_onset = 0.2` biases matching toward events that are close in absolute time.
