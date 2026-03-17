"""Synchronization utilities.

Translated from the MATLAB ``sync/`` directory of the BML toolbox.
"""

import math

import numpy as np
import pandas as pd

from bml.utils import getopt

_PTT = 9  # precision for time tolerance = -log10(timetol)


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

def _matlab_round(x):
    """Round to nearest integer, with ties away from zero (MATLAB convention).

    ``numpy.round`` uses banker's rounding (ties to even) which differs from
    MATLAB's ``round`` which rounds ties away from zero.
    """
    x = np.asarray(x, dtype=float)
    return (np.sign(x) * np.floor(np.abs(x) + 0.5)).astype(int)


def _round_significant(x, n):
    """Round *x* to *n* significant digits.

    Equivalent to MATLAB ``round(x, n, 'significant')``.

    Parameters
    ----------
    x : float
        Value to round.
    n : int
        Number of significant digits.

    Returns
    -------
    float
    """
    if x == 0:
        return 0.0
    magnitude = int(np.floor(np.log10(abs(x))))
    return round(x, -magnitude + (n - 1))


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

def time2idx(cfg, time, skip_factor=1):
    """Calculate sample indices from times and file coordinates.

    Translated from ``bml_time2idx.m``.

    Parameters
    ----------
    cfg : dict
        Configuration with keys ``t1``, ``s1``, ``t2``, ``s2`` and
        optionally ``nSamples``.
    time : array_like
        Numeric vector of times.
    skip_factor : int, optional
        Integer downsample factor (default ``1``).

    Returns
    -------
    numpy.ndarray
        Integer sample indices corresponding to each time.

    Raises
    ------
    ValueError
        If any computed index exceeds *nSamples*.
    """
    skip_factor = int(round(skip_factor))
    time = np.asarray(time, dtype=float)

    t1 = np.round(getopt(cfg, 't1'), _PTT)
    s1 = math.ceil(getopt(cfg, 's1') / skip_factor)
    t2 = np.round(getopt(cfg, 't2'), _PTT)
    s2 = math.floor(getopt(cfg, 's2') / skip_factor)
    n_samples = getopt(cfg, 'nSamples')

    idx = _matlab_round(
        (t2 * s1 - s2 * t1 + (s2 - s1) * np.round(time, _PTT))
        / (t2 - t1)
    )

    if n_samples is not None and np.any(idx > n_samples):
        raise ValueError("index exceeds number of samples in file")

    return idx


def idx2time(cfg, idx, skip_factor=1):
    """Calculate sample midpoint times from indices and file coordinates.

    Translated from ``bml_idx2time.m``.

    Parameters
    ----------
    cfg : dict or pandas.DataFrame
        Configuration with keys/columns ``t1``, ``s1``, ``t2``, ``s2``.
        When a :class:`~pandas.DataFrame` with more than one row the
        sample ranges ``(s1, s2)`` must not overlap.
    idx : array_like
        Integer sample indices.
    skip_factor : int, optional
        Integer downsample factor (default ``1``).

    Returns
    -------
    numpy.ndarray
        Times corresponding to each index.

    Raises
    ------
    ValueError
        If sample ranges in a multi-row DataFrame overlap.
    """
    skip_factor = int(round(skip_factor))
    idx = np.asarray(idx, dtype=float)

    # --- Multi-row DataFrame (split sync) --------------------------------
    if isinstance(cfg, pd.DataFrame) and len(cfg) > 1:
        # Inline overlap check: sort by s1 and verify no overlap
        sorted_df = cfg.sort_values('s1').reset_index(drop=True)
        for i in range(len(sorted_df) - 1):
            if sorted_df['s2'].iloc[i] >= sorted_df['s1'].iloc[i + 1]:
                raise ValueError(
                    "sample ranges (s1, s2) must not overlap"
                )

        time = np.zeros(len(idx))
        for _, row in cfg.iterrows():
            t1 = np.round(float(row['t1']), _PTT)
            s1 = float(row['s1'])
            t2 = np.round(float(row['t2']), _PTT)
            s2 = float(row['s2'])
            Fs = _round_significant(
                (s2 - s1) / np.round(t2 - t1, _PTT), _PTT
            )

            if skip_factor > 1:
                s1 = math.ceil(s1 / skip_factor)
                s2 = math.floor(s2 / skip_factor)
                t1 = t1 + (skip_factor - 1) * 0.5 / Fs
                t2 = t2 - (skip_factor - 1) * 0.5 / Fs
                Fs = _round_significant(
                    (s2 - s1) / np.round(t2 - t1, _PTT), _PTT
                )

            mask = (idx >= s1) & (idx <= s2)
            time[mask] = (
                idx[mask] / Fs - 0.5 / Fs
                + (s2 * t1 - t2 * s1) / (s2 - s1)
            )
        return time

    # --- Single-row dict or single-row DataFrame -------------------------
    if isinstance(cfg, pd.DataFrame):
        cfg = cfg.iloc[0].to_dict()

    t1 = np.round(getopt(cfg, 't1'), _PTT)
    s1 = getopt(cfg, 's1')
    t2 = np.round(getopt(cfg, 't2'), _PTT)
    s2 = getopt(cfg, 's2')
    Fs = _round_significant(
        (s2 - s1) / np.round(t2 - t1, _PTT), _PTT
    )

    if skip_factor > 1:
        s1 = math.ceil(s1 / skip_factor)
        s2 = math.floor(s2 / skip_factor)
        t1 = t1 + (skip_factor - 1) * 0.5 / Fs
        t2 = t2 - (skip_factor - 1) * 0.5 / Fs
        Fs = _round_significant(
            (s2 - s1) / np.round(t2 - t1, _PTT), _PTT
        )

    time = idx / Fs - 0.5 / Fs + (s2 * t1 - t2 * s1) / (s2 - s1)
    return time
