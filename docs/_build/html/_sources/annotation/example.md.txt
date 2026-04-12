# Complete Worked Example

**Goal**: Extract high-gamma power from clean trial windows, per stimulus condition.

## Step 1 — Load session ROI and events

```matlab
roi = bml_roi_table(bml_info_raw(struct('folder', PATH_DATA)));
sync_roi = load(fullfile(PATH_SYNC, 'sync_roi_final.mat'));

events = bml_annot_read_tsv( ...
  'sub-DM1001_ses-intraop_task-speech_events.tsv');
% events.starts = master-clock seconds (post-sync)
% events.trial_type = {'go','nogo',...}
```

## Step 2 — Create trial windows

```matlab
% 0.5 s before onset to 2 s after
trial_windows = bml_annot_extend(events, 0.5, 2.0);
fprintf('Total trials: %d\n', height(trial_windows));
```

## Step 3 — Artifact rejection

```matlab
artifacts = bml_annot_read_tsv('artifacts.tsv');
artifacts = bml_annot_filter(artifacts, session_window);

% Remove any trial >50% covered by artifacts
cfg = []; cfg.overlap = 0.5;
clean_trials = bml_annot_filterout(cfg, trial_windows, artifacts);
fprintf('Trials after rejection: %d / %d\n', ...
  height(clean_trials), height(trial_windows));
```

## Step 4 — Per-trial artifact coverage

```matlab
cov = bml_annot_coverage(artifacts, clean_trials);
clean_trials.artifact_pct = cov.coverage * 100;
```

## Step 5 — Get clean sub-windows (difference)

```matlab
clean_windows = bml_annot_difference(clean_trials, artifacts);
% clean_windows.x_id_ links each fragment back to the original trial
```

## Step 6 — Transfer trial metadata to sub-windows

```matlab
cfg = []; cfg.select = {'trial_type', 'value', 'session_id'};
clean_windows = bml_annot_transfer(cfg, clean_windows, clean_trials);
```

## Step 7 — Extract high-gamma power

```matlab
hg_roi = sync_roi(strcmp(sync_roi.filetype,'trellis') & ...
                  strcmp(sync_roi.chantype,'hg'), :);

log_pwr = @(raw) 10*log10(mean(raw.trial{1}(1,:).^2) + eps);

cfg = []; cfg.roi = hg_roi;
results = bml_annot_calculate(cfg, clean_windows, 'log_power_hg', log_pwr);
```

## Step 8 — Summary statistics

```matlab
cfg = []; cfg.groupby = 'trial_type';
stats = bml_annot_describe(cfg, results);
disp(stats);
% trial_type | variable | mean | std | count | median | ...
```

## Step 9 — Visualize

```matlab
cfg = []; cfg.y = 'trial_type'; cfg.facet = 'session_id';
bml_annot_plot(cfg, clean_trials);
title('Clean trials by condition');
```

## Data flow

```{mermaid}
flowchart TD
    A[session ROI + BIDS TSV] --> B[bml_annot_extend\ntrial windows]
    B --> C[bml_annot_filterout\nartifact rejection]
    C --> D[bml_annot_coverage\nper-trial artifact %]
    C --> E[bml_annot_difference\nclean sub-windows]
    E --> F[bml_annot_transfer\nadd trial metadata]
    F --> G[bml_annot_calculate\nHG power per window]
    G --> H[bml_annot_describe\nstats per condition]
    H --> I[results table]
```
