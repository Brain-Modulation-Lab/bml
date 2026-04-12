# BML Toolbox

**Brain Modulation Laboratory · MGH · v1.0**

The BML toolbox is a MATLAB library for intraoperative and clinical neurophysiology data analysis (ECoG, LFP, MER). It provides a uniform data model based on **annotation tables** and a complete pipeline for synchronizing multi-device recordings to a single master clock.

---

## Quick start

```matlab
% 1. Build a session ROI table from files on disk
roi = bml_roi_table(bml_info_raw(struct('folder', '/data/p001/s01')));

% 2. Read task events from a BIDS TSV file
events = bml_annot_read_tsv('sub-p001_ses-intraop_task-speech_events.tsv');

% 3. Create ±0.5s analysis windows around each event
windows = bml_annot_extend(events, 0.5);

% 4. Remove windows overlapping artifacts
clean = bml_annot_filterout(windows, artifacts);

% 5. Load synchronized neural data for a time range
cfg.roi = sync_roi(strcmp(sync_roi.filetype,'trellis'),:);
cfg.toi = [52350, 52400];
raw = bml_load_continuous(cfg);
```

---

## Contents

```{toctree}
:maxdepth: 2
:caption: Part I · Annotation Tables

annotation/index
annotation/schema
annotation/roi_table
annotation/creating
annotation/set_operations
annotation/grouping
annotation/joins_features
annotation/encoding_viz
annotation/example
annotation/reference
```

```{toctree}
:maxdepth: 2
:caption: Part II · Synchronization

sync/index
sync/overview
sync/audio
sync/neuroomega
sync/psychtoolbox
sync/dp_matching
sync/consolidation
sync/best_practices
sync/internals
sync/diagnostics
```

```{toctree}
:maxdepth: 1
:caption: Reference

api/index
changelog
```

---

## Design philosophy

:::{grid} 3
:gutter: 2

:::{grid-item-card} Annotation tables everywhere
Every BML function accepts and returns annotation tables — tables with `id`, `starts`, `ends`, `duration` columns. This makes all functions composable.
:::

:::{grid-item-card} Single master clock
After synchronization, every timestamp is on the Trellis/Ripple hardware clock. You never need to track which device produced a data point.
:::

:::{grid-item-card} Non-destructive
Raw files are never modified. Sync state lives in `sync_roi` tables that can be recomputed at any time.
:::
:::
