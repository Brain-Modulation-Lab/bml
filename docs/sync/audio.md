# Synchronizing Zoom Audio to Ripple

Two approaches are available depending on what signals are shared between Trellis and Zoom.

## Approach A — Shared analog waveform (`bml_sync_analog`)

Both devices record the same click-track on an analog channel. `bml_sync_analog` cross-correlates the shared waveform in two passes: a coarse envelope pass (±300 s) followed by a fine LPF pass (±1 s).

```matlab
sync_channels = table( ...
  {'trellis';'zoom'}, {'ainp1';'Ch1'}, {'analog';'analog'}, ...
  'VariableNames', {'filetype','channel','chantype'});
sync_channels.threshold = [NaN; NaN];

cfg = [];
cfg.roi             = roi(ismember(roi.filetype,{'trellis','zoom'}), :);
cfg.chunks          = chunks;
cfg.master_filetype = 'trellis';
cfg.sync_channels   = sync_channels;
cfg.timewarp        = true;
cfg.env_scan        = 300;   % coarse: ±300 s envelope xcorr
cfg.lpf_scan        = 1;     % fine:   ±1 s LPF xcorr
cfg.lpf_max_freq    = 4000;
cfg.chunk_extend    = 5;     % load 5 s extra each side
sync_roi_analog = bml_sync_analog(cfg);
```

### Per-chunk pipeline inside `bml_sync_analog`

For each chunk and each slave filetype:
1. Load master sync channel (`ainp1`) and slave sync channel (`Ch1`) as `FT_DATATYPE_RAW`
2. **Coarse alignment**: envelope cross-correlation (`bml_timewarp` with `method='envelope'`, `scan=300`)
3. **Fine alignment**: LPF cross-correlation (`bml_timewarp` with `method='low-pass-filter'`, `scan=1`)
4. Output: `t1`, `t2` updated to master-clock times; `warpfactor = ws1_env × ws1_lpf`

---

## Approach B — Digital triggers via audio-peak detection (`bml_sync_audio_event`)

When Zoom only carries a click track (no waveform shared with Trellis on an analog channel), Ripple's **digital event log** (TTL pulses) is used as master. `bml_sync_audio_event` detects audio peaks in Zoom and matches them to the Trellis digital event times.

```matlab
% master_events come from Ripple's DIGITAL event channel (TTL pulses)
master_events = bml_read_event(trellis_roi);
master_events = bml_event2annot([], master_events);
master_events = master_events(master_events.value == 1, :);

cfg = [];
cfg.roi           = roi(strcmp(roi.filetype,'zoom'), :);
cfg.master_events = master_events;  % ← digital events from Ripple
cfg.scan          = 100;  cfg.scan_step = 0.1;
cfg.min_rph       = 0.5;  % peaks > 50% of file max amplitude
cfg.min_ipi       = 0.05; % peaks > 50 ms apart
cfg.timewarp      = false;
cfg.diagnostic_plot = true;
sync_roi_zoom = bml_sync_audio_event(cfg);
% sync_roi_zoom.sync_channel == 'digital'
```

:::{note}
**When to use each approach:**
- **Approach A** (analog): more robust, exploits full waveform shape. Use when both devices record the sync channel as a continuous waveform.
- **Approach B** (digital peaks): use when only TTL pulses are logged by Ripple and the Zoom recording only carries acoustic clicks.
:::

---

## `bml_timealign` — cross-correlation internals

1. Compute scan range (max possible shift before files stop overlapping)
2. Pad and resample both signals to `resample_freq` (default 10 kHz)
3. Preprocess: **envelope** (abs of Hilbert → 100 Hz) or **LPF** (4th-order Butterworth)
4. Normalize: subtract robust median, divide by robust std (16th–84th percentile)
5. `xcorr(..., 'coeff')` → find peak lag → `slave_delta_t`

## `bml_timewarp` — linear drift correction

The warp model:

$$w(t) = t_{\text{pivot}} + wt_0 + (t - t_{\text{pivot}}) \cdot ws_1$$

Cost function minimized by Nelder-Mead simplex:

$$\mathcal{L}(wt_0, ws_1) = -\frac{\langle f(w(\mathbf{t})), p \rangle}{\|p\|^2} + \left(\frac{wt_0}{P_{\delta t}}\right)^2 + \left(\frac{ws_1 - 1}{P_\xi}\right)^4$$

where $p$ = master signal, $f(t)$ = interpolated slave signal, $P_{\delta t}$ and $P_\xi$ are penalty scales.
