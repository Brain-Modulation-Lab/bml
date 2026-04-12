# Changelog

## v1.0 — April 2026

### Documentation
- Comprehensive annotation guide covering all 30+ `bml_annot_*` functions with TikZ visualizations, interval algebra math, and worked examples
- Synchronization guide covering all four device types: Ripple/Trellis, Zoom, NeuroOmega, and Psychtoolbox
- Merged guide (`bml_guide_v1.pdf`, 51 pages) with two parts: Annotation Tables and Synchronization Pipeline
- ReadTheDocs site (Sphinx + MyST + furo) at `docs/`
- Clarified that `bml_sync_audio_event` uses Ripple's digital TTL log as master (not analog waveform)
- Documented exact-match fallback strategy for Psychtoolbox synchronization
- Added best-practices section: method selection, chunking strategy, BIDS conventions, Python migration roadmap

### Functions
- `bml_annot_blocks` — run-length encoding of label columns, returns blocks + edge annotations, preserves `group_by` information
- `bml_annot_plot` — now supports facet plots with numeric variables

### Bug fixes
- `bml_argus_raw2table` — now handles empty records
- `bml_sync_match_events` — added `weight_onset` parameter (defaults to 0); weights are normalized to sum to 1

---

## v0.2 — March 2026

### Functions
- `bml_sync_digital` — updated to use `bml_sync_match_events` (5-feature DP); `sim_threshold` parameter added
- `bml_sync_audio_event` — sets `sync_channel='digital'` in output
- `bml_annot_describe` — added `median`, `iqr`, `q25`, `q75` output columns

### Bug fixes
- `bml_sync_consolidate` — fixed group handling when `cfg.group = []`
- `bml_annot_filterout` — `cfg.overlap` threshold now correctly applied as fraction (0–1)

---

## v0.1 — January 2026

Initial structured release. Core annotation functions and synchronization pipeline stabilized.

### Functions included
- Full `bml_annot_*` suite: table, extend, filter, filterout, intersect, union, difference, consolidate, coverage, overlap, left_join, transfer, calculate, describe, detect, match, t0, rowbind, conform_to, rename, sample, plot
- Sync suite: analog, audio_event, neuroomega_event, digital, match_events, consolidate, check
- Coordinate system: idx2time, time2idx, annot2coord, roi2coord
- I/O: roi_table, info_raw, annot_read_tsv, annot_write_tsv, event2annot, annot2raw, raw2annot, annot2spike

---

## v0.0 — 2018-02-20

Pre-release. Initial commits covering core data structures and FieldTrip integration.
