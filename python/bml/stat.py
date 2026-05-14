"""Statistical functions for BML.

Python translations of MATLAB functions from the BML toolbox stat/
directory.
"""

import warnings
from itertools import combinations

import numpy as np
from scipy.stats import norm


# -- robust_std ---------------------------------------------------------------

def robust_std(data, center=None):
    """Row-wise robust estimation of standard deviation.

    Translated from ``bml_robust_std.m``.

    The estimator works by finding the quantile of absolute deviations
    from *center* and scaling by the corresponding normal quantile.
    It iterates over increasing quantile levels starting at 0.5 until
    the estimate is numerically distinguishable from zero, or returns 0.

    Parameters
    ----------
    data : numpy.ndarray
        1-D or 2-D array.  If 2-D, the robust standard deviation is
        computed independently for each row.
    center : numpy.ndarray or None, optional
        Center of the distribution for each row.  Must be a 1-D array
        with one element per row when *data* is 2-D.  Defaults to the
        row-wise ``nanmedian``.

    Returns
    -------
    numpy.ndarray
        1-D array of length ``data.shape[0]`` (or length 1 for a 1-D
        input) containing the robust standard deviation estimates.
    """
    data = np.atleast_2d(np.asarray(data, dtype=float))

    if center is None:
        center = np.nanmedian(data, axis=1)
    else:
        center = np.asarray(center, dtype=float).ravel()

    n_rows = data.shape[0]
    result = np.zeros(n_rows)

    for i in range(n_rows):
        row = data[i, :]
        s = np.nanquantile(np.abs(row), 0.95)
        # eps(s) in MATLAB equals np.spacing(s) in NumPy
        eps_s = np.spacing(s)
        p = 0.5
        while result[i] < 1e4 * eps_s and p < 1:
            abs_dev = np.abs(row - center[i])
            result[i] = (
                np.nanquantile(abs_dev, p) / norm.ppf((1 + p) / 2)
            )
            p += 0.05
        if result[i] < 1e4 * eps_s:
            result[i] = 0.0

    return result


# -- FDR ----------------------------------------------------------------------

def FDR(p_list, alpha=0.05, corrected=False):
    """False Discovery Rate (Benjamini & Hochberg, 1995).

    Translated from ``bml_FDR.m`` by Edden Gerber.

    Parameters
    ----------
    p_list : array_like
        1-D sequence of p-values.
    alpha : float, optional
        Desired significance threshold (default ``0.05``).
    corrected : bool, optional
        If ``True``, apply the Benjamini & Yekutieli (2001)
        dependency correction (default ``False``).

    Returns
    -------
    ind : numpy.ndarray
        0-based indices into *p_list* of the significant p-values.
    thres : float
        The p-value threshold used.
    """
    p_list = np.asarray(p_list, dtype=float).ravel()
    n_vals = len(p_list)
    num_tests = n_vals

    # Sort descending
    p_sorted = np.sort(p_list)[::-1]

    # Build comparison vector (descending rank / num_tests * alpha)
    ranks_desc = np.arange(num_tests, 0, -1)  # num_tests, ..., 1
    if corrected:
        correction = np.sum(np.arange(1, num_tests + 1) / num_tests)
        comp = ranks_desc / num_tests * alpha / correction
    else:
        comp = ranks_desc / num_tests * alpha

    # comp((end-n_vals+1):end) – since n_vals == num_tests this is a no-op,
    # but kept for fidelity.
    comp = comp[-n_vals:]

    # Find first (in descending-sorted order) p-value that passes
    indices = np.where(p_sorted <= comp)[0]
    if len(indices) == 0:
        thres = 0.0
    else:
        thres = p_sorted[indices[0]]

    ind = np.where(p_list <= thres)[0]
    return ind, thres


# -- fdr_bh ------------------------------------------------------------------

def fdr_bh(pvals, q=0.05, method='pdep', report=False):
    """Benjamini-Hochberg / Benjamini-Yekutieli FDR procedure.

    Translated from ``bml_fdr_bh.m`` by David M. Groppe.

    Executes the Benjamini & Hochberg (1995) or Benjamini & Yekutieli
    (2001) procedure for controlling the false discovery rate of a
    family of hypothesis tests, and returns FCR-adjusted confidence
    interval coverage.

    Parameters
    ----------
    pvals : array_like
        Vector or matrix of p-values.
    q : float, optional
        Desired false discovery rate (default ``0.05``).
    method : str, optional
        ``'pdep'`` for the original BH procedure (valid under
        independence or positive dependence) or ``'dep'`` for the BY
        procedure (valid under arbitrary dependence).  Default
        ``'pdep'``.
    report : bool, optional
        If ``True``, print a summary to stdout (default ``False``).

    Returns
    -------
    h : numpy.ndarray
        Boolean array of the same shape as *pvals*; ``True`` where the
        null hypothesis is rejected.
    crit_p : float
        Critical p-value threshold.  0 if nothing is significant.
    adj_ci_cvrg : float
        FCR-adjusted confidence interval coverage, or ``NaN`` if no
        p-values are significant.
    adj_p : numpy.ndarray
        Adjusted p-values (same shape as *pvals*).  Values can exceed 1.

    Raises
    ------
    ValueError
        If *pvals* contains values outside [0, 1] or *method* is
        unrecognised.
    """
    pvals = np.asarray(pvals, dtype=float)
    original_shape = pvals.shape

    if np.any(pvals < 0):
        raise ValueError("Some p-values are less than 0.")
    if np.any(pvals > 1):
        raise ValueError("Some p-values are greater than 1.")

    method = method.lower()
    if method not in ('pdep', 'dep'):
        raise ValueError("method must be 'pdep' or 'dep'.")

    # Flatten to a sorted row vector (matching MATLAB behaviour for
    # matrices with more than one row or > 2 dimensions).
    p_flat = pvals.ravel()
    sort_ids = np.argsort(p_flat, kind='mergesort')
    p_sorted = p_flat[sort_ids]
    unsort_ids = np.argsort(sort_ids, kind='mergesort')
    m = len(p_sorted)

    ranks = np.arange(1, m + 1, dtype=float)

    if method == 'pdep':
        thresh = ranks * q / m
        wtd_p = m * p_sorted / ranks
    else:  # 'dep'
        denom = m * np.sum(1.0 / ranks)
        thresh = ranks * q / denom
        wtd_p = denom * p_sorted / ranks

    # Compute adjusted p-values (D.H.J. Poot's efficient algorithm)
    adj_p = np.full(m, np.nan)
    wtd_p_sindex = np.argsort(wtd_p, kind='mergesort')
    wtd_p_sorted = wtd_p[wtd_p_sindex]
    nextfill = 0  # 0-based
    for k in range(m):
        if wtd_p_sindex[k] >= nextfill:
            adj_p[nextfill:wtd_p_sindex[k] + 1] = wtd_p_sorted[k]
            nextfill = wtd_p_sindex[k] + 1
            if nextfill >= m:
                break
    adj_p = adj_p[unsort_ids].reshape(original_shape)

    # Determine significance
    rej = p_sorted <= thresh
    rej_indices = np.where(rej)[0]
    if len(rej_indices) == 0:
        crit_p = 0.0
        h = np.zeros(original_shape, dtype=bool)
        adj_ci_cvrg = np.nan
    else:
        max_id = rej_indices[-1]
        crit_p = p_sorted[max_id]
        h = (pvals <= crit_p)
        adj_ci_cvrg = 1.0 - thresh[max_id]

    if report:
        n_sig = int(np.sum(p_sorted <= crit_p))
        word = "is" if n_sig == 1 else "are"
        print(
            f"Out of {m} tests, {n_sig} {word} significant using a "
            f"false discovery rate of {q}."
        )
        if method == 'pdep':
            print(
                "FDR/FCR procedure used is guaranteed valid for "
                "independent or positively dependent tests."
            )
        else:
            print(
                "FDR/FCR procedure used is guaranteed valid for "
                "independent or dependent tests."
            )

    return h, crit_p, adj_ci_cvrg, adj_p


# -- permutation_test --------------------------------------------------------

def permutation_test(sample1, sample2, permutations, sidedness='both',
                     exact=False):
    """Permutation test for a difference in means.

    Translated from ``permutationTest.m`` by Laurens R Krol.

    Parameters
    ----------
    sample1 : array_like
        Measurements from the first (experimental) sample.
    sample2 : array_like
        Measurements from the second (control) sample.
    permutations : int
        Number of random permutations.  Ignored when *exact* is
        ``True``.
    sidedness : str, optional
        ``'both'`` (default) for a two-sided test, ``'smaller'`` to
        test that ``mean(sample1) < mean(sample2)``, or ``'larger'``
        to test that ``mean(sample1) > mean(sample2)``.
    exact : bool, optional
        If ``True``, enumerate all possible combinations instead of
        using random permutations (default ``False``).  Only feasible
        for small sample sizes.

    Returns
    -------
    p : float
        The p-value.
    observed_difference : float
        ``nanmean(sample1) - nanmean(sample2)``.
    effect_size : float
        Hedges' *g* effect size.
    """
    sample1 = np.asarray(sample1, dtype=float).ravel()
    sample2 = np.asarray(sample2, dtype=float).ravel()

    all_observations = np.concatenate([sample1, sample2])
    observed_difference = np.nanmean(sample1) - np.nanmean(sample2)

    n1 = len(sample1)
    n2 = len(sample2)
    n_total = n1 + n2

    # Hedges' g (pooled std with Bessel's correction)
    pooled_std = np.sqrt(
        ((n1 - 1) * np.nanstd(sample1, ddof=1) ** 2
         + (n2 - 1) * np.nanstd(sample2, ddof=1) ** 2)
        / (n_total - 2)
    )
    effect_size = (
        observed_difference / pooled_std if pooled_std != 0 else np.nan
    )

    if exact:
        all_combinations = list(combinations(range(n_total), n1))
        permutations = len(all_combinations)

    random_differences = np.empty(permutations)

    for n in range(permutations):
        if exact:
            idx1 = np.array(all_combinations[n])
            idx2 = np.setdiff1d(np.arange(n_total), idx1)
        else:
            perm = np.random.permutation(n_total)
            idx1 = perm[:n1]
            idx2 = perm[n1:]

        random_differences[n] = (
            np.nanmean(all_observations[idx1])
            - np.nanmean(all_observations[idx2])
        )

    if sidedness == 'both':
        p = (
            (np.sum(np.abs(random_differences) > np.abs(observed_difference)) + 1)
            / (permutations + 1)
        )
    elif sidedness == 'smaller':
        p = (
            (np.sum(random_differences < observed_difference) + 1)
            / (permutations + 1)
        )
    elif sidedness == 'larger':
        p = (
            (np.sum(random_differences > observed_difference) + 1)
            / (permutations + 1)
        )
    else:
        raise ValueError(
            f"sidedness must be 'both', 'smaller', or 'larger', "
            f"got {sidedness!r}"
        )

    return p, observed_difference, effect_size
