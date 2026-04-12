# Function Reference

## Complete function list

| Function | Operation | Inputs | Output | Typical use |
|----------|-----------|--------|--------|-------------|
| `bml_annot_table` | Constructor | table/struct/numeric | annotation table | Create any table |
| `bml_roi_table` | Constructor | table + file info | ROI table | Build file index |
| `bml_annot_read_tsv` | I/O | filename | annotation table | Load BIDS event logs |
| `bml_annot_write_tsv` | I/O | annot, filename | file on disk | Export synced events |
| `bml_event2annot` | Conversion | FT events, roi | annotation table | Convert Ripple events |
| `bml_annot2raw` | Encoding | annot, roi | FT raw | Binary signal from events |
| `bml_raw2annot` | Encoding | FT raw | annotation table | Extract time metadata |
| `bml_annot2spike` | Conversion | annot, roi | FT spike | Spike data structure |
| `bml_annot_extend` | Dilation | annot, ext1, ext2 | annotation table | Analysis windows |
| `bml_annot_filter` | Selection | annot, filter | annotation table | Restrict to window |
| `bml_annot_filterout` | Exclusion | annot, filter | annotation table | Artifact rejection |
| `bml_annot_intersect` | Intersection | x, y | annotation table | Clip to overlap |
| `bml_annot_union` | Union | x, y | annotation table | Merge intervals |
| `bml_annot_difference` | Subtraction | x, y | annotation table | Remove artifacts |
| `bml_annot_consolidate` | Grouping | annot, criterion | annotation table | Run-length, batch |
| `bml_annot_blocks` | RLE | annot, label col | blocks + edges | State segmentation |
| `bml_annot_shadow` | Gap filling | annot | annotation table | Pre/post baselines |
| `bml_annot_coverage` | Measurement | x (numerator), y | coverage table | Artifact QC |
| `bml_annot_overlap` | Validation | annot | overlap pairs | Find conflicts |
| `bml_annot_left_join` | Join | left, right, keys | annotation table | Add metadata |
| `bml_annot_transfer` | Temporal join | annot, transfer | annotation table | Assign epoch labels |
| `bml_annot_calculate` | Aggregation | epoch, raw, fns | feature table | Extract signal features |
| `bml_annot_describe` | Statistics | annot, groupby | stats table | Summarize per group |
| `bml_annot_detect` | Detection | threshold, raw | annotation table | Find HG bursts |
| `bml_annot_match` | Template | data, template | annotation table | Pattern search |
| `bml_annot_t0` | Translation | annot, t0 | annotation table | Event-relative time |
| `bml_annot_rowbind` | Concatenation | A, B, ... | annotation table | Merge table list |
| `bml_annot_conform_to` | Schema | template, annot | annotation table | Pre-concat fix |
| `bml_annot_rename` | Projection | annot, old, new | annotation table | Column rename |
| `bml_annot_sample` | Sampling | annot, n/frac | annotation table | Random subselect |
| `bml_annot_plot` | Visualization | annot, cfg | figure | Inspect epochs |

## Interval algebra summary

| Operation | Formula | Function |
|-----------|---------|----------|
| Overlap test | $a_1 < b_2 \;\text{AND}\; a_2 > b_1$ | `bml_annot_filter`, `bml_annot_intersect` |
| Intersection | $[\max(a_1,b_1),\;\min(a_2,b_2)]$ | `bml_annot_intersect` |
| Union (two overlapping) | $[\min(a_1,b_1),\;\max(a_2,b_2)]$ | `bml_annot_union` |
| Extension | $[a_1 - e_1,\; a_2 + e_2]$ | `bml_annot_extend` |
| Coverage | $\sum_i |x_i \cap y_j| / |y_j|$ | `bml_annot_coverage` |
| Translation | $[a_1 - t_0,\; a_2 - t_0]$ | `bml_annot_t0` |
