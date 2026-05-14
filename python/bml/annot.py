"""Annotation table functions for BML.

Python translations of MATLAB functions from the BML toolbox annot/
directory.  Annotation tables are represented as :class:`pandas.DataFrame`
objects with at least the columns ``id``, ``starts``, ``ends`` and
``duration``.  The table description is stored in ``df.attrs['description']``.
"""

import os
import re
import warnings

import numpy as np
import pandas as pd


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

def _reorder_vars(df, first_cols):
    """Reorder columns so *first_cols* come first, preserving others."""
    first = [c for c in first_cols if c in df.columns]
    rest = [c for c in df.columns if c not in first]
    return df[first + rest]


def _get_description(df):
    """Return the description stored on a DataFrame, or ''."""
    if isinstance(df, pd.DataFrame):
        return df.attrs.get("description", "")
    return ""


def _set_description(df, description):
    """Set description on a DataFrame."""
    df.attrs["description"] = description or ""
    return df


def _conform_to(template, other):
    """Conform *other* to have the same columns as *template*."""
    for col in template.columns:
        if col not in other.columns:
            other = other.copy()
            other[col] = np.nan
    return other[template.columns]


def _collapse_rows(rows, additive=None):
    """Collapse multiple annotation rows into a single summary row."""
    additive = additive or []
    result = {
        "starts": rows["starts"].min(),
        "ends": rows["ends"].max(),
        "cons_duration": rows["duration"].sum(),
        "id_starts": rows["id"].min(),
        "id_ends": rows["id"].max(),
        "cons_n": len(rows),
    }
    skip = set(result.keys()) | set(additive)
    for col in rows.columns:
        if col in skip or col in ("id", "duration"):
            continue
        vals = rows[col].dropna().unique()
        if len(vals) == 1:
            result[col] = vals[0]
        else:
            result[col] = np.nan
    for col in additive:
        if col in rows.columns:
            result[col] = rows[col].sum()
    return result


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

def annot_table(x=None, description=None):
    """Create or validate an annotation DataFrame.

    Translated from ``bml_annot_table.m``.

    Parameters
    ----------
    x : DataFrame, dict, list, numpy.ndarray, or None
        Input data.  Must contain ``starts`` and ``ends`` columns (or be
        coercible to a two-column table that will be renamed).
    description : str or None
        Optional description stored in ``df.attrs['description']``.

    Returns
    -------
    pandas.DataFrame
        Annotation table with columns ``id``, ``starts``, ``ends``,
        ``duration`` followed by any extra columns.
    """
    # Handle empty / None
    if x is None or (isinstance(x, pd.DataFrame) and x.empty):
        df = pd.DataFrame()
        return _set_description(df, description or "")

    # Convert various types to DataFrame
    if isinstance(x, np.ndarray):
        if x.ndim == 1:
            x = x.reshape(-1, 1)
        df = pd.DataFrame(x)
    elif isinstance(x, dict):
        df = pd.DataFrame(x)
    elif isinstance(x, list):
        df = pd.DataFrame(x)
    elif isinstance(x, pd.DataFrame):
        df = x.copy()
    else:
        df = pd.DataFrame(x)

    if description is None:
        description = _get_description(df) or ""

    if df.empty:
        return _set_description(df, description)

    # Ensure 'starts' column
    if "starts" not in df.columns:
        if len(df.columns) <= 2:
            cols = list(df.columns)
            df = df.rename(columns={cols[0]: "starts"})
        else:
            raise ValueError("x should have variable 'starts'")

    # Ensure 'ends' column
    if "ends" not in df.columns:
        if len(df.columns) == 1:
            df["ends"] = df["starts"]
        elif len(df.columns) == 2:
            cols = list(df.columns)
            other = [c for c in cols if c != "starts"][0]
            df = df.rename(columns={other: "ends"})
        else:
            raise ValueError("x should have variable 'ends'")

    # Ensure 'id' column
    if "id" not in df.columns:
        df = df.sort_values("starts").reset_index(drop=True)
        df.insert(0, "id", range(1, len(df) + 1))
    else:
        if df["id"].nunique() < len(df):
            raise ValueError("inconsistent id variable")
        df = df.sort_values("id").reset_index(drop=True)

    # Recalculate duration
    if "duration" in df.columns:
        df = df.drop(columns=["duration"])
    df["duration"] = df["ends"] - df["starts"]

    df = _reorder_vars(df, ["id", "starts", "ends", "duration"])
    return _set_description(df, description)


def annot_overlap(annot, timetol=1e-5):
    """Find overlapping annotations.

    Translated from ``bml_annot_overlap.m``.

    Parameters
    ----------
    annot : pandas.DataFrame
        Annotation table with ``starts``, ``ends``, ``id`` columns.
    timetol : float, optional
        Time tolerance in seconds (default ``1e-5``).

    Returns
    -------
    pandas.DataFrame
        Table with columns ``starts``, ``ends``, ``id1``, ``id2`` for
        each overlapping pair, or an empty DataFrame if none found.
    """
    annot = annot_table(annot)
    if len(annot) <= 1:
        return pd.DataFrame(columns=["starts", "ends", "id1", "id2"])

    rows = []
    i, j = 0, 1
    n = len(annot)
    while i < n and j < n:
        si, ei = annot["starts"].iloc[i], annot["ends"].iloc[i]
        sj, ej = annot["starts"].iloc[j], annot["ends"].iloc[j]
        if ej - si > timetol and ei - sj > timetol:
            rows.append({
                "starts": max(si, sj),
                "ends": min(ei, ej),
                "id1": annot["id"].iloc[i],
                "id2": annot["id"].iloc[j],
            })
            j += 1
        elif ei - sj <= timetol:
            i += 1
            j = i + 1
        elif ej - si <= timetol:
            j += 1
        else:
            raise RuntimeError("Unsupported input annotations tables")

    if not rows:
        return pd.DataFrame(columns=["starts", "ends", "id1", "id2"])
    return pd.DataFrame(rows)


def annot_intersect(x, y, keep="both", groupby=None, groupby_x=None,
                    groupby_y=None, description=None, warn=True):
    """Intersection of two annotation tables.

    Translated from ``bml_annot_intersect.m``.

    Parameters
    ----------
    x, y : pandas.DataFrame
        Annotation tables.  *y* should have no overlapping annotations.
    keep : str
        Which extra variables to keep: ``'both'``, ``'none'``, ``'x'``,
        or ``'y'``.
    groupby, groupby_x, groupby_y : str or None
        Column name(s) to group by before intersecting.
    description : str or None
        Description for the result.
    warn : bool
        Warn on variable name conflicts.

    Returns
    -------
    pandas.DataFrame
        Intersection annotation table.
    """
    x = annot_table(x)
    y = annot_table(y)

    if x.empty:
        return x.copy()
    if y.empty:
        return y.copy()

    x_desc = _get_description(x) or "x"
    y_desc = _get_description(y) or "y"
    if x_desc == y_desc:
        x_desc, y_desc = x_desc + "_x", y_desc + "_y"

    xidn = f"{x_desc}_id"
    yidn = f"{y_desc}_id"

    if description is None:
        description = f"intersect_{x_desc}_{y_desc}"

    if groupby_x is None:
        groupby_x = groupby
    if groupby_y is None:
        groupby_y = groupby

    # Determine groups
    if groupby_x is None and groupby_y is None:
        x = x.copy()
        y = y.copy()
        x["_groupby_"] = 1
        y["_groupby_"] = 1
        groupby_x = groupby_y = "_groupby_"
        groups = [1]
    elif groupby_x is not None and groupby_y is not None:
        gx = set(x[groupby_x].unique())
        gy = set(y[groupby_y].unique())
        groups = sorted(gx & gy)
        if not groups:
            return _set_description(pd.DataFrame(), description)
    else:
        raise ValueError("groupby_x and groupby_y must both be given or both be None")

    result_rows = []
    for g in groups:
        xg = x[x[groupby_x] == g]
        yg = y[y[groupby_y] == g]
        if yg.empty or xg.empty:
            continue

        # Two-pointer intersection
        xg = xg.sort_values("starts").reset_index(drop=True)
        yg = yg.sort_values("starts").reset_index(drop=True)

        has_x_overlap = not annot_overlap(xg).empty if len(xg) > 1 else False

        i, j = 0, 0
        while i < len(xg) and j < len(yg):
            xs, xe = xg["starts"].iloc[i], xg["ends"].iloc[i]
            ys, ye = yg["starts"].iloc[j], yg["ends"].iloc[j]
            if xs < ye and xe > ys:
                result_rows.append({
                    "starts": max(xs, ys),
                    "ends": min(xe, ye),
                    xidn: xg["id"].iloc[i],
                    yidn: yg["id"].iloc[j],
                })
                if has_x_overlap:
                    if xe < ye or j >= len(yg) - 1:
                        i += 1
                        j = 0
                    else:
                        j += 1
                else:
                    if xe < ye:
                        i += 1
                    else:
                        j += 1
            elif xe <= ys:
                i += 1
                if has_x_overlap:
                    j = 0
            elif xs >= ye:
                j += 1
            else:
                raise RuntimeError("Unsupported input annotations tables")

    if not result_rows:
        return _set_description(pd.DataFrame(), description)

    result = pd.DataFrame(result_rows)
    result = annot_table(result, description)

    # Remove groupby helper column
    if "_groupby_" in result.columns:
        result = result.drop(columns=["_groupby_"])
    if "_groupby_" in x.columns:
        x = x.drop(columns=["_groupby_"])
    if "_groupby_" in y.columns:
        y = y.drop(columns=["_groupby_"])

    # Join extra variables based on keep
    keep = keep.lower().replace(" ", "").replace("_", "").replace("keep", "")
    if keep in ("both", "x"):
        x_join = x.drop(columns=["starts", "ends"], errors="ignore")
        if groupby_x and groupby_x in x_join.columns and groupby_x != "_groupby_":
            x_join = x_join.drop(columns=[groupby_x])
        x_join = x_join.rename(columns={"id": xidn})
        # Prefix common columns
        for col in x_join.columns:
            if col != xidn and col in result.columns:
                x_join = x_join.rename(columns={col: f"{x_desc}_{col}"})
        result = result.merge(x_join, on=xidn, how="left")

    if keep in ("both", "y"):
        y_join = y.drop(columns=["starts", "ends"], errors="ignore")
        if groupby_y and groupby_y in y_join.columns and groupby_y != "_groupby_":
            y_join = y_join.drop(columns=[groupby_y])
        y_join = y_join.rename(columns={"id": yidn})
        for col in y_join.columns:
            if col != yidn and col in result.columns:
                y_join = y_join.rename(columns={col: f"{y_desc}_{col}"})
        result = result.merge(y_join, on=yidn, how="left")

    return _set_description(result, description)


def annot_filter(annot, filter_annot, overlap=0, description=None):
    """Filter annotations by intersection with *filter_annot*.

    Translated from ``bml_annot_filter.m``.

    Parameters
    ----------
    annot : pandas.DataFrame
        Annotations to filter.
    filter_annot : pandas.DataFrame
        Filter annotations.
    overlap : float, optional
        Minimum fraction of overlap required (default ``0`` = touch).
    description : str or None
        Description for the result.

    Returns
    -------
    pandas.DataFrame
        Filtered annotations.
    """
    annot = annot_table(annot)
    filter_annot = annot_table(filter_annot)

    if annot.empty:
        return annot.copy()

    # Fast path for single-row touch filter
    if overlap == 0 and len(filter_annot) == 1:
        fs = filter_annot["starts"].iloc[0]
        fe = filter_annot["ends"].iloc[0]
        return annot[(annot["starts"] < fe) & (annot["ends"] > fs)].copy()

    inter = annot_intersect(
        annot,
        filter_annot[["id", "starts", "ends", "duration"]],
        keep="none",
    )
    if inter.empty:
        return _set_description(pd.DataFrame(columns=annot.columns), description)

    a_desc = _get_description(annot) or "x"
    annot_id_col = f"{a_desc}_id"
    if annot_id_col not in inter.columns:
        # Try default names
        for col in inter.columns:
            if col.endswith("_id") and col != "id":
                annot_id_col = col
                break

    if overlap > 0:
        # Sum intersection durations per annot_id
        inter_dur = inter.groupby(annot_id_col)["duration"].sum().reset_index()
        inter_dur.columns = [annot_id_col, "intersect_dur"]
        merged = annot[annot["id"].isin(inter_dur[annot_id_col])].merge(
            inter_dur, left_on="id", right_on=annot_id_col, how="left"
        )
        ratio = merged["intersect_dur"] / merged["duration"]
        keep_ids = merged.loc[(ratio >= overlap) | ratio.isna(), "id"]
        return annot[annot["id"].isin(keep_ids)].copy()
    else:
        return annot[annot["id"].isin(inter[annot_id_col])].copy()


def annot_consolidate(annot, criterion=None, additive=None, groupby=None,
                      description=None):
    """Consolidate (merge) overlapping or contiguous annotations.

    Translated from ``bml_annot_consolidate.m``.

    Parameters
    ----------
    annot : pandas.DataFrame
        Annotation table.
    criterion : callable or None
        Function accepting a DataFrame of candidate rows and returning
        ``True`` if they should be merged.  Default: merge if the last
        row's ``starts`` is <= the max ``ends`` of previous rows.
    additive : list of str or None
        Column names whose values should be summed during collapse.
    groupby : str or None
        Column name to group by before consolidating.
    description : str or None
        Description for the result.

    Returns
    -------
    pandas.DataFrame
        Consolidated annotation table.
    """
    annot = annot_table(annot)
    if annot.empty:
        return annot.copy()

    if description is None:
        description = "cons_" + (_get_description(annot) or "annot")
    additive = additive or []

    if criterion is None:
        def criterion(rows):
            return rows["starts"].iloc[-1] <= rows["ends"].iloc[:-1].max()

    if groupby is None:
        groups = [None]
    else:
        groups = sorted(annot[groupby].unique())

    all_cons = []
    for g in groups:
        if g is None:
            ag = annot
        else:
            ag = annot[annot[groupby] == g]

        ag = ag.sort_values("starts").reset_index(drop=True)

        if len(ag) <= 1:
            row = _collapse_rows(ag, additive)
            all_cons.append(row)
            continue

        i = 0
        j = 1
        while i < len(ag):
            if j == 1:
                curr_rows = ag.iloc[i:i + 1]

            if i + j >= len(ag):
                all_cons.append(_collapse_rows(curr_rows, additive))
                break

            merge_rows = ag.iloc[i:i + j + 1]
            if criterion(merge_rows):
                curr_rows = merge_rows
                j += 1
                if i + j > len(ag):
                    all_cons.append(_collapse_rows(curr_rows, additive))
                    break
            else:
                all_cons.append(_collapse_rows(curr_rows, additive))
                i = i + j
                j = 1
                if i == len(ag) - 1:
                    all_cons.append(_collapse_rows(ag.iloc[i:i + 1], additive))
                    break

    if not all_cons:
        return _set_description(pd.DataFrame(), description)

    result = pd.DataFrame(all_cons)
    result = annot_table(result, description)
    return result


def annot_rename(annot, *args, **kwargs):
    """Rename columns of an annotation table.

    Translated from ``bml_annot_rename.m``.

    Can be called as::

        annot_rename(df, 'old1', 'new1', 'old2', 'new2')
        annot_rename(df, old1='new1', old2='new2')

    Parameters
    ----------
    annot : pandas.DataFrame
        Annotation table.
    *args : str
        Alternating old/new column name pairs.
    **kwargs : str
        Old=new column name mappings.

    Returns
    -------
    pandas.DataFrame
        Renamed annotation table.
    """
    rename_map = {}
    if args:
        if len(args) % 2 != 0:
            raise ValueError("Column rename arguments must come in pairs")
        for i in range(0, len(args), 2):
            rename_map[args[i]] = args[i + 1]
    rename_map.update(kwargs)

    for old_name in rename_map:
        if old_name not in annot.columns:
            raise ValueError(f"variable {old_name} not present in annotation table")

    desc = _get_description(annot)
    result = annot.rename(columns=rename_map)
    return _set_description(result, desc)


def annot_read(filename, **kwargs):
    """Read an annotation table from a tab-delimited file.

    Translated from ``bml_annot_read.m``.

    Parameters
    ----------
    filename : str
        Path to the file.
    **kwargs
        Additional keyword arguments passed to :func:`pandas.read_csv`.

    Returns
    -------
    pandas.DataFrame
        Annotation table.
    """
    kwargs.setdefault("sep", "\t")
    kwargs.setdefault("na_values", ["NA"])

    df = pd.read_csv(filename, **kwargs)
    name = os.path.splitext(os.path.basename(filename))[0]

    if "onset" in df.columns and "duration" in df.columns:
        df = df.rename(columns={"onset": "starts"})
        df["ends"] = df["starts"] + df["duration"]
        df["id"] = range(1, len(df) + 1)

    return annot_table(df, name)


def annot_read_tsv(filename, append_cols_from_filename=False, **kwargs):
    """Read a BIDS-style TSV annotation table.

    Translated from ``bml_annot_read_tsv.m``.

    Parameters
    ----------
    filename : str
        Path to the ``.tsv`` file.
    append_cols_from_filename : bool, optional
        If ``True``, extract ``subject_id``, ``session_id``, ``task_id``
        from BIDS-style filename patterns.
    **kwargs
        Additional keyword arguments passed to :func:`pandas.read_csv`.

    Returns
    -------
    pandas.DataFrame
        Annotation table.
    """
    kwargs.setdefault("sep", "\t")
    kwargs.setdefault("na_values", ["n/a"])

    df = pd.read_csv(filename, **kwargs)
    name = os.path.splitext(os.path.basename(filename))[0]

    if "onset" in df.columns and "duration" in df.columns:
        df = df.rename(columns={"onset": "starts"})
        df["ends"] = df["starts"] + df["duration"]
        df["id"] = range(1, len(df) + 1)
        df = annot_table(df, name)

    if append_cols_from_filename:
        bids_keys = {"sub": "subject_id", "ses": "session_id", "task": "task_id"}
        for key, col in bids_keys.items():
            pattern = rf"(?<={key}-)[a-zA-Z0-9-]+"
            matches = re.findall(pattern, filename)
            if matches and col not in df.columns:
                df[col] = matches[0]

    return annot_table(df, name)


def annot_write(annot, filename):
    """Write an annotation table to a tab-delimited file.

    Translated from ``bml_annot_write.m``.

    Parameters
    ----------
    annot : pandas.DataFrame
        Annotation table.
    filename : str
        Output file path.
    """
    annot = annot_table(annot)
    df = annot.copy()

    _, ext = os.path.splitext(filename)
    if ext == ".tsv":
        df = df.drop(columns=["id", "ends"], errors="ignore")

    df.to_csv(filename, sep="\t", index=False)


def annot_write_tsv(annot, filename):
    """Write an annotation table in BIDS TSV format.

    Translated from ``bml_annot_write_tsv.m``.

    Renames ``starts`` to ``onset`` and drops ``id`` and ``ends`` columns.

    Parameters
    ----------
    annot : pandas.DataFrame
        Annotation table.
    filename : str
        Output file path.
    """
    annot = annot_table(annot)
    df = annot.rename(columns={"starts": "onset"})
    df = df.drop(columns=["id", "ends"], errors="ignore")
    df.to_csv(filename, sep="\t", index=False)


def annot_rowbind(*args):
    """Row-bind multiple annotation DataFrames.

    Translated from ``bml_annot_rowbind.m``.

    Parameters
    ----------
    *args : pandas.DataFrame
        Annotation tables to concatenate.

    Returns
    -------
    pandas.DataFrame
        Combined annotation table.
    """
    frames = [df for df in args if df is not None and not df.empty]
    if not frames:
        return pd.DataFrame()

    # Conform all to the first frame's columns
    template = frames[0]
    conformed = [template]
    for df in frames[1:]:
        conformed.append(_conform_to(template, df))

    result = pd.concat(conformed, ignore_index=True)
    if "id" in result.columns:
        result = result.drop(columns=["id"])
    if "starts" in result.columns and "ends" in result.columns:
        result = annot_table(result)
    return result


def annot_coverage(x, y, groupby_x=None, groupby_y=None, colname="coverage"):
    """Calculate fraction of *y* covered by *x*.

    Translated from ``bml_annot_coverage.m``.

    Parameters
    ----------
    x : pandas.DataFrame
        Numerator annotations.
    y : pandas.DataFrame
        Denominator annotations.
    groupby_x : str or None
        Column name to group *x* by.
    groupby_y : str or None
        Column name to group *y* by.
    colname : str
        Name for the coverage column (default ``'coverage'``).

    Returns
    -------
    pandas.DataFrame
        Copy of *y* with an added coverage column.
    """
    x = annot_table(x)
    y = annot_table(y)

    if groupby_x is None:
        groups = [None]
    else:
        groups = sorted(x[groupby_x].unique())

    result_rows = []
    for g in groups:
        if g is None:
            xg = x
        else:
            xg = x[x[groupby_x] == g].sort_values("starts")

        yg = y if groupby_y is None else y[y[groupby_y] == g]

        for _, yrow in yg.iterrows():
            if xg.empty:
                cvg = 0.0
            else:
                t = yrow["starts"]
                cvg = 0.0
                for _, xrow in xg.iterrows():
                    if t >= yrow["ends"]:
                        break
                    if xrow["starts"] < yrow["ends"] and xrow["ends"] > t:
                        s = max(xrow["starts"], t)
                        e = min(xrow["ends"], yrow["ends"])
                        cvg += e - s
                        t = e
                cvg = cvg / yrow["duration"] if yrow["duration"] > 0 else 0.0

            row_data = yrow.to_dict()
            if groupby_x and g is not None:
                row_data[groupby_x] = g
            row_data[colname] = cvg
            result_rows.append(row_data)

    if not result_rows:
        return pd.DataFrame()

    result = pd.DataFrame(result_rows)
    if "id" in result.columns:
        result = result.drop(columns=["id"])
    return annot_table(result)
