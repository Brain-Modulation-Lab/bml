# Annotation Table Schema

## Creating a table

`bml_annot_table(x)` is the constructor. It accepts a MATLAB `table`, `struct`, or two-column numeric matrix `[starts, ends]`.

```matlab
% From a table with starts/ends columns
T = table([1.0; 2.5; 4.0], [1.5; 3.0; 4.8], ...
          'VariableNames', {'starts','ends'});
T.trial_type = {'go'; 'nogo'; 'go'};
annot = bml_annot_table(T);
% id=[1;2;3] auto-assigned, duration=[0.5;0.5;0.8] computed

% From a numeric matrix
annot = bml_annot_table([10 10.5; 11.2 11.7; 13.5 14.2]);

% From a struct
s.starts = [10; 11.2]; s.ends = [10.5; 11.7]; s.label = {'A';'B'};
annot = bml_annot_table(struct2table(s));
```

## Invariants

:::{warning}
`id` is **reassigned** at every `bml_annot_table()` call. Never use `id` as a persistent cross-table key. Use a dedicated column (e.g., `trial_id`, `file_id`) for stable cross-references.
:::

- Rows are sorted by `starts` on every call.
- `duration` is always recomputed from `ends − starts`.
- Any existing `duration` column is dropped and replaced.
- Instantaneous events (spikes, button presses): set `ends = starts`.

## Utilities

| Function | What it does |
|----------|--------------|
| `bml_annot_rowbind(A, B, ...)` | Vertically concatenate tables, conforming schemas |
| `bml_annot_rename(annot, old, new)` | Rename columns |
| `bml_annot_conform_to(template, annot)` | Fill missing columns to match template schema |
| `bml_annot_t0(cfg, annot)` | Shift all times by `−t0` (event-relative axis) |
| `bml_annot_sample(cfg, annot)` | Random row sample (`cfg.n` or `cfg.frac`) |
| `bml_annot_describe(cfg, annot)` | Descriptive stats per group |
