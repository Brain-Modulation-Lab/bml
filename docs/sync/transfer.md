# Sync Transfer Functions

After synchronization, you have `(s1, t1, s2, t2)` coordinates for the **file you actually synced** — e.g. the Trellis `.ns5` file or the NeuroOmega `analog` channel. But the same session contains other files at different sampling rates (`.ns2`, `.ns3`) and other channel types (`micro`, `macro`, `emg`) that were never directly synced.

The transfer functions **propagate sync coordinates** from the synced file to all the others — without re-running sync.

## The problem

```{mermaid}
flowchart LR
    A[bml_sync_analog\nsyncs ns5 only] --> B[sync_roi\nfiletype=trellis.ns5\nFs=30000]
    B -->|transfer| C[sync_roi\nfiletype=trellis.ns2\nFs=1000]
    B -->|transfer| D[sync_roi\nfiletype=trellis.ns3\nFs=2000]

    E[bml_sync_neuroomega_event\nsyncs analog chantype] --> F[sync_roi\nchantype=analog\nFs=2750]
    F -->|transfer| G[sync_roi\nchantype=micro\nFs=44000]
    F -->|transfer| H[sync_roi\nchantype=macro\nFs=44000]
    F -->|transfer| I[sync_roi\nchantype=emg]
```

---

## `bml_sync_transfer_trellis_filetype`

Trellis records the same session simultaneously as multiple NSx files at different sampling rates. You sync once (on `.ns5`), then transfer.

**How it works**: rescales sample indices using the nominal Fs ratio, then recomputes `t1`, `t2` from the file's absolute start/end times.

$$s_1^{\text{new}} = \left\lceil \frac{F_s^{\text{new}}}{F_s} \cdot \left(s_1 - \tfrac{1}{2}\right) \right\rceil, \quad t_1^{\text{new}} = t_0 + \frac{s_1^{\text{new}} - \tfrac{1}{2}}{F_{s,\text{eff}}^{\text{new}}} - \text{delay}$$

where $t_0$ is the absolute file start time reconstructed from the synced coordinates.

```matlab
cfg = [];
cfg.roi           = sync_ns5;          % synced ns5 rows
cfg.filetype      = 'trellis.ns2';     % target
cfg.sync_filetype = 'trellis.ns5';     % source
cfg.delay         = 0;                 % optional: correct LPF phase delay (s)
sync_ns2 = bml_sync_transfer_trellis_filetype(cfg);
```

| Parameter | Default | Meaning |
|-----------|---------|---------|
| `filetype` | `'trellis.ns2'` | Target filetype to generate sync for |
| `sync_filetype` | `'trellis.ns5'` | Source filetype already in `cfg.roi` |
| `extension` | from filetype | File extension to look for on disk |
| `delay` | `0` | Phase delay correction in seconds (e.g. for online LPF) |
| `timetol` | `1e-4` | Warn if file durations differ by more than this |

:::{note}
`bml_sync_transfer_nsx_filetype` is functionally identical but uses `round(..., 'significant')` for more robust Fs computation with certain NSx file formats. Use it when `bml_sync_transfer_trellis_filetype` produces spurious coordinate values.
:::

---

## `bml_sync_transfer_neuroomega_chantype`

A single NeuroOmega `.mat` file contains multiple channel types, each with its own internal clock stored as `ChannelName_TimeBegin` / `ChannelName_TimeEnd` variables. Sync is typically done on the `analog` channel (2750 Hz). This function re-anchors the coordinates to any other channel type.

**Channel types available**:

| `chantype` | Example channel | Fs |
|------------|----------------|-----|
| `analog` | `CANALOG_IN_1` | 2750 Hz |
| `micro` | `CRAW_01___Central` | 44 kHz |
| `micro_hp` | `CSPK_01___Central` | 44 kHz |
| `micro_lfp` | `CLFP_01___Central` | ~1.4 kHz |
| `macro` | `CMacro_RAW_01___Central` | 44 kHz |
| `macro_lfp` | `CMacro_LFP_01___Central` | ~1.4 kHz |
| `emg` | `CEMG_1___01` | variable |
| `events` | — | uses micro time |

**How it works**: reads `TimeBegin`/`TimeEnd` from the `.mat` header for both the original (sync) channel and the target channel, then re-anchors `t1`/`t2` by the difference in internal clocks.

```matlab
cfg = [];
cfg.roi      = sync_ao_analog;   % rows with chantype='analog'
cfg.chantype = 'micro';
sync_ao_micro = bml_sync_transfer_neuroomega_chantype(cfg);

% Also transfer to macro
cfg.chantype = 'macro';
sync_ao_macro = bml_sync_transfer_neuroomega_chantype(cfg);
```

| Parameter | Default | Meaning |
|-----------|---------|---------|
| `chantype` | required | Target channel type |
| `roi` | required | Sync table for source chantype |
| `time_channel` | auto | Specific channel name in target chantype |
| `sync_time_channel` | auto | Specific channel name in source chantype |
| `filetype` | `'neuroomega.mat'` | File type to process |

---

## Complete pipeline example

```matlab
% --- Trellis ---
% Sync on ns5 (30 kHz, used for sync signal quality)
cfg = [];
cfg.roi             = roi(strcmp(roi.filetype,'trellis.ns5'), :);
cfg.chunks          = chunks;
cfg.master_filetype = 'trellis';
cfg.sync_channels   = sync_channels;
sync_ns5 = bml_sync_analog(cfg);

% Transfer to ns2 (1 kHz LFP band)
cfg_t = [];
cfg_t.roi           = sync_ns5;
cfg_t.filetype      = 'trellis.ns2';
cfg_t.sync_filetype = 'trellis.ns5';
sync_ns2 = bml_sync_transfer_trellis_filetype(cfg_t);

% --- NeuroOmega ---
% Sync on analog channel
sync_ao_analog = bml_sync_neuroomega_event(cfg_ao);

% Transfer to micro and macro
cfg_micro = struct('roi', sync_ao_analog, 'chantype', 'micro');
cfg_macro = struct('roi', sync_ao_analog, 'chantype', 'macro');
sync_ao_micro = bml_sync_transfer_neuroomega_chantype(cfg_micro);
sync_ao_macro = bml_sync_transfer_neuroomega_chantype(cfg_macro);

% --- Consolidate everything ---
cfg_cons = [];
cfg_cons.roi = [sync_ns5; sync_ns2; sync_ao_analog; sync_ao_micro; sync_ao_macro];
sync_roi_final = bml_sync_consolidate(cfg_cons);
```

---

## Why not just re-sync each file type?

- The `analog` channel is chosen for sync because it has **lower Fs** (2750 Hz vs 44 kHz), making cross-correlation faster and more robust.
- The `.ns5` file is chosen for Trellis sync because it has the **highest Fs** and cleanest waveform representation of the click track.
- Re-syncing each file type separately introduces **independent estimation errors**. Transfer guarantees that all channel types share the exact same sync estimate, maintaining perfect internal consistency.
