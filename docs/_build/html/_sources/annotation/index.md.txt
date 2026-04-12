# Annotation Tables

An **annotation table** is the universal data structure in BML. Every time-stamped object — a trial, a spike, a file, an artifact window — is stored as an annotation table.

## In this section

```{toctree}
:maxdepth: 1

schema
roi_table
creating
set_operations
grouping
joins_features
encoding_viz
example
reference
```

## The four mandatory columns

| Column | Type | Description |
|--------|------|-------------|
| `id` | integer | Auto-assigned, sorted by `starts`. Not stable across calls — never use as a persistent key. |
| `starts` | double | Interval start time, seconds on master clock. |
| `ends` | double | Interval end time (≥ `starts`). Instantaneous events: `ends = starts`. |
| `duration` | double | `ends − starts`. Always recomputed — never trust a stale `duration`. |

Any additional columns (trial type, channel, value, …) are preserved through all BML operations.

## Function map

```{mermaid}
flowchart TD
    A[bml_annot_table] --> B[Annotation Table]
    C[bml_annot_read_tsv] --> B
    D[bml_event2annot] --> B
    E[bml_info_raw + bml_roi_table] --> F[ROI Table]
    F --> B

    B --> G[Set operations\nbml_annot_filter/out\nbml_annot_intersect\nbml_annot_union\nbml_annot_difference]
    B --> H[Grouping\nbml_annot_consolidate\nbml_annot_blocks\nbml_annot_shadow\nbml_annot_coverage]
    B --> I[Joining\nbml_annot_left_join\nbml_annot_transfer]
    B --> J[Features\nbml_annot_calculate\nbml_annot_detect\nbml_annot_describe]
    B --> K[Encoding\nbml_annot2raw\nbml_annot_plot]
```
