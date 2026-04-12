# The ROI Table and Coordinate System

An **ROI (Region of Interest) table** is an annotation table extended with file metadata and **sync coordinates** — the four numbers `(s1, t1, s2, t2)` that define the mapping from sample index to master-clock time.

## Extra columns

| Column | Meaning |
|--------|---------|
| `folder` | Directory containing the file |
| `name` | Filename |
| `nSamples` | Total number of samples |
| `Fs` | Nominal sampling rate (Hz) |
| `filetype` | e.g. `'trellis'`, `'zoom'`, `'neuroomega'` |
| `chantype` | e.g. `'analog'`, `'digital'`, `'lfp'` |
| **`s1`** | First anchor: sample index |
| **`t1`** | First anchor: master-clock time of sample `s1` |
| **`s2`** | Second anchor: sample index |
| **`t2`** | Second anchor: master-clock time of sample `s2` |

## The linear coordinate map

Two anchor points define a linear (affine) map between sample index and time:

$$F_{s,\text{eff}} = \frac{s_2 - s_1}{t_2 - t_1}$$

$$t(i) = \frac{i}{F_{s,\text{eff}}} - \frac{0.5}{F_{s,\text{eff}}} + \frac{s_2 t_1 - t_2 s_1}{s_2 - s_1}$$

$$i(t) = \text{round}\!\left(\frac{t_2 s_1 - s_2 t_1 + (s_2 - s_1)\,t}{t_2 - t_1}\right)$$

After synchronization, $F_{s,\text{eff}} \neq F_s$ because the slave clock drifted. Always use `bml_idx2time` — never divide by `Fs` directly.

## Why sample midpoints?

Sample $i$ occupies the window $[(i-1)/F_s,\; i/F_s)$. Its **midpoint** is $i/F_s - 0.5/F_s$.

The default initialization sets `t1` and `t2` to midpoints:
- `s1 = 1`, `t1 = starts + 0.5/Fs`
- `s2 = nSamples`, `t2 = ends − 0.5/Fs`

These are unreliable OS timestamps until synchronization updates them to master-clock times.

## Usage

```matlab
% Build ROI table from a folder scan
roi = bml_roi_table(bml_info_raw(struct('folder', '/data/p001/s01')));

% Convert sample index → master-clock time
t = bml_idx2time(roi(1,:), 15000);

% Convert master-clock time → sample index
i = bml_time2idx(roi(1,:), 52312.5);

% After sync, t1/t2 are updated to hardware-clock times
% The warpfactor encodes the clock drift: Fs_eff = Fs * warpfactor
```

:::{note}
`bml_idx2time` uses 9-decimal-place precision (`pTT = 9`) to avoid floating-point accumulation errors over long recordings.
:::
