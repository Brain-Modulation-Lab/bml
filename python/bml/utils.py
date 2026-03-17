"""Utility functions for BML.

Python translations of MATLAB functions from the BML toolbox utils/ and
signal/ directories.
"""

import json
import warnings

import numpy as np


def getopt(cfg, key, default=None, emptymeaningful=False):
    """Get a value from a configuration dict.

    Translated from ``bml_getopt.m``.

    Parameters
    ----------
    cfg : dict or None
        Configuration mapping.  ``None`` or an empty dict is treated as
        an absent configuration and *default* is returned.
    key : str
        The key to look up.
    default : object, optional
        Value returned when *key* is not present or (unless
        *emptymeaningful* is ``True``) when the stored value is ``None``.
    emptymeaningful : bool, optional
        When ``False`` (the default) a ``None`` value is replaced by
        *default*.  Set to ``True`` to allow ``None`` through.

    Returns
    -------
    object
        The looked-up value, or *default*.
    """
    if cfg is None or (isinstance(cfg, dict) and len(cfg) == 0):
        val = default
    elif isinstance(cfg, dict):
        val = cfg.get(key, default)
    else:
        raise TypeError(
            f"cfg must be a dict or None, got {type(cfg).__name__}"
        )

    if val is None and default is not None and not emptymeaningful:
        val = default

    return val


def map_values(element, domain, codomain, non_domain=None):
    """Map elements from *domain* to *codomain*.

    Translated from ``bml_map.m``.

    For each item in *element*, its position in *domain* is found and the
    corresponding *codomain* value is returned.

    Parameters
    ----------
    element : list or numpy.ndarray
        Values to map.
    domain : list or numpy.ndarray
        Known input values.
    codomain : list or numpy.ndarray
        Corresponding output values (same length as *domain*).
    non_domain : object, optional
        Value used for elements that are not found in *domain*.  If
        ``None`` (the default) a ``ValueError`` is raised for missing
        elements.

    Returns
    -------
    list or numpy.ndarray
        Mapped values.  A ``numpy.ndarray`` is returned when *element*
        is a ``numpy.ndarray`` and *codomain* is also a
        ``numpy.ndarray``; otherwise a ``list``.

    Raises
    ------
    ValueError
        If *domain* and *codomain* have different lengths, or if an
        element is not found in *domain* and *non_domain* is ``None``.
    """
    if len(domain) != len(codomain):
        raise ValueError(
            "domain and codomain must have the same length"
        )

    # Build a lookup: domain value -> first codomain value
    # (mirrors MATLAB find(..., 1) which returns the first match)
    lookup = {}
    for d, c in zip(domain, codomain):
        if d not in lookup:
            lookup[d] = c

    use_array = isinstance(element, np.ndarray) and isinstance(
        codomain, np.ndarray
    )

    mapped = []
    for e in element:
        if e in lookup:
            mapped.append(lookup[e])
        elif non_domain is not None:
            mapped.append(non_domain)
        else:
            raise ValueError(
                f"element {e!r} not found in domain and no non_domain default given"
            )

    if use_array:
        return np.array(mapped)
    return mapped


def getidx(element, collection):
    """Get first indices of *element* values in *collection*.

    Translated from ``bml_getidx.m``.

    Parameters
    ----------
    element : list or numpy.ndarray
        Values to locate.
    collection : list or numpy.ndarray
        The collection to search in.

    Returns
    -------
    list of int
        For each item in *element*, the 0-based index of its first
        occurrence in *collection*, or ``-1`` if not found.

    Notes
    -----
    The MATLAB version returns 1-based indices with 0 for "not found".
    This Python version uses the conventional 0-based indexing with
    ``-1`` for "not found".
    """
    # Convert to list for uniform handling
    col_list = list(collection)

    indices = []
    for e in element:
        try:
            indices.append(col_list.index(e))
        except ValueError:
            indices.append(-1)

    return indices


def readjson(filename):
    """Read a JSON file and return its parsed contents.

    Translated from ``readjson.m``.

    Parameters
    ----------
    filename : str or path-like
        Path to the JSON file.

    Returns
    -------
    object
        The decoded JSON data (typically a ``dict`` or ``list``).
    """
    with open(filename, "r") as fid:
        return json.load(fid)


def _round_sigfigs(x, sigfigs):
    """Round *x* to *sigfigs* significant figures.

    Equivalent to MATLAB ``round(x, sigfigs, 'signif')``.
    """
    if x == 0:
        return 0.0
    magnitude = int(np.floor(np.log10(abs(x))))
    return round(x, -magnitude + (sigfigs - 1))


def getFs(raw, cfg=None):
    """Return the sampling frequency of a raw data structure.

    Translated from ``bml_getFs.m``.

    Parameters
    ----------
    raw : dict
        Raw data structure with a ``'time'`` key whose value is a list
        (or other iterable) of 1-D array-like time vectors, one per
        trial.
    cfg : dict or None, optional
        Configuration dict.  Recognised keys:

        * ``timetol`` – absolute time tolerance in seconds
          (default ``1e-9``).
        * ``reltimetol`` – relative time tolerance
          (default ``1e-4``).
        * ``freqsignif`` – number of significant figures for rounding
          the sampling frequency (default ``4``).

    Returns
    -------
    float
        Estimated sampling frequency in Hz rounded to *freqsignif*
        significant figures.
    """
    timetol = getopt(cfg, "timetol", 1e-9)
    reltimetol = getopt(cfg, "reltimetol", 1e-4)
    freqsignif = getopt(cfg, "freqsignif", 4)

    trials = raw["time"]
    n_trials = len(trials)

    median_dt = np.full(n_trials, np.nan)
    timetol_offenders = []
    reltimetol_offenders = []

    for t in range(n_trials):
        dts = np.diff(np.asarray(trials[t], dtype=float))
        median_dt[t] = np.median(dts)
        dt_range = np.ptp(dts)  # equivalent to MATLAB range()
        if dt_range > timetol:
            timetol_offenders.append(t)
        if median_dt[t] != 0 and dt_range / median_dt[t] > reltimetol:
            reltimetol_offenders.append(t)

    if timetol_offenders:
        warnings.warn(
            f"trials {timetol_offenders} don't comply with timetol of {timetol}"
        )
    if reltimetol_offenders:
        warnings.warn(
            f"trials {reltimetol_offenders} don't comply with reltimetol of {reltimetol}"
        )

    mean_median_dt = np.mean(median_dt)

    # Check across-trial consistency
    if n_trials > 1:
        cross_range = np.ptp(median_dt)
        if cross_range > timetol:
            warnings.warn("timetol violated across trials")
        if mean_median_dt != 0 and cross_range / mean_median_dt > reltimetol:
            warnings.warn("reltimetol violated across trials")

    return _round_sigfigs(1.0 / mean_median_dt, freqsignif)
