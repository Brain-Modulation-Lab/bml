# `interior_quantile(x, q, m)` — specification (pseudocode)

## Goal

Return a **quantile-like** value from a vector `x` while enforcing a strict **rank–index interior constraint** designed to avoid selecting points that are plausibly part of boundary recovery (e.g., stimulation artifact edges).

The function behaves like a standard quantile near the tails, but may be **undefined** for quantiles near `0.5` because the strict interior constraint can make “middle ranks” inadmissible (worst-case).

---

## Inputs

- `x`: vector of length `N` (real values)
- `q`: desired quantile in `[0, 1]`
- `m`: non-negative integer “margin” in **samples**

---

## Output

On success, return a record/tuple with at least:

- `value`: the selected value from `x`
- `index`: the original index in `x` (1-based in pseudocode)
- `rank`: the ascending value-rank `k` of the selected element (optional but useful)
- `eligible_count`: number of eligible elements `M` (optional)

On failure, return `FAIL` (or `(NaN, flag=false)` depending on your style).

---

## Definitions

### Ascending order / ranks

Let:

- `ord = argsort(x)` be indices sorted by **ascending** value (stable sort recommended for ties).
- Then `ord[k]` is the original index `i ∈ {1..N}` of the **k-th smallest** element.
- `k` is the **ascending rank** (order-statistic index).

### Strict rank–index interior constraint

For each rank `k` (1..N), define its candidate index:

- `i = ord[k]`

Rank `k` is **eligible** if:

- `i > k + m`  **and**  `i < N - k - m`

Equivalently (integer interval form):

- `i ∈ [k + m + 1,  N - k - m - 1]`

This ties *how extreme the value is* (rank `k`) to *how far from the time-window boundaries the sample occurs* (index `i`).

---

## Endpoint convention (`q = 0` and `q = 1`)

`q = 0` and `q = 1` should not automatically fail.

We therefore **clamp**:

\[
q \leftarrow \mathrm{clip}\left(q,\; \frac{1}{N},\; \frac{N-1}{N}\right)
\]

So:
- `q=0 → 1/N`
- `q=1 → (N-1)/N`

---

## Symmetry for high quantiles (`q > 0.5`)

To avoid awkward “top ranks may be inadmissible” issues and to keep symmetry, define high quantiles using negation:

\[
\text{interior\_quantile}(x,q,m) = -\,\text{interior\_quantile\_low}(-x, 1-q, m)
\quad \text{for } q > 0.5
\]

That is: **flip order** by negating values and use `1-q` on the low-side function.

---

## Existence conditions

Let `eligible` be the list of eligible ranks (ascending). Let `M = length(eligible)`.

For low-side selection with target `t = ceil(q*N)`, the value exists **iff**:

- `M > 0` and `t ≤ M`

If not, return `FAIL`.

> Note: even if the admissible interval `[k+m+1, N-k-m-1]` is non-empty for a given `k`, the specific data-dependent index `ord[k]` may still fall outside it. Hence, existence is data-dependent.

---

## Pseudocode

### Main function

```text
function interior_quantile(x, q, m):

    N = length(x)
    if N == 0: return FAIL
    if m < 0 or not integer(m): return FAIL
    if q < 0 or q > 1: return FAIL

    if N == 1:
        return (value=x[1], index=1, rank=1, eligible_count=1)

    # Clamp q away from endpoints so q=0 and q=1 do not fail by definition
    q = clip(q, 1/N, (N-1)/N)

    if q > 0.5:
        # high-side via symmetry (flip order)
        res = interior_quantile_low(-x, 1 - q, m)     # 1-q ∈ (0, 0.5]
        if res == FAIL: return FAIL
        return (value = -res.value,
                index = res.index,
                eligible_count = res.eligible_count)
    else:
        return interior_quantile_low(x, q, m)
```

### Low-side helper (only for `q ∈ (0, 0.5]`)

```text
function interior_quantile_low(x, q, m):

    N = length(x)

    ord = argsort(x)    # ascending stable sort recommended

    eligible = empty list of ranks k
    for k in 1..N:
        i = ord[k]      # original index of k-th smallest element

        # strict interior constraint
        if (i > k + m) and (i < N - k - m):
            append k to eligible

    M = length(eligible)
    if M == 0: return FAIL

    # Select the (q*N)-th eligible point (NOT the first eligible ≥ q*N)
    t = ceil(q * N)
    if t < 1: t = 1              # defensive; should not be needed after clamping
    if t > M: return FAIL         # existence condition

    k_star = eligible[t]
    i_star = ord[k_star]
    return (value = x[i_star],
            index = i_star,
            rank  = k_star,
            eligible_count = M)
```

---

## Notes on ties

If `x` contains ties:
- Use a **stable** sort for `argsort(x)` so the function is deterministic.
- The definition above treats the sorted position `k` as the “rank” even with ties.

---

## Worst-case admissibility (necessary, not sufficient)

For a fixed rank `k`, the admissible index interval is non-empty iff:

\[
k+m+1 \le N-k-m-1 \iff 2k \le N - 2m - 2
\]

If you expect `k ≈ qN`, a rough necessary condition for low-side selection is:

\[
q \lesssim \frac{1}{2} - \frac{m+1}{N}
\]

and by symmetry, for high-side selection:

\[
q \gtrsim \frac{1}{2} + \frac{m+1}{N}
\]

Quantiles too close to `0.5` can therefore be incompatible with the strict interior constraint in the worst case.

---

## Typical use in ERNA peak–trough amplitude

A common pattern is:

- `hi = interior_quantile(x, 0.95, m).value`
- `lo = interior_quantile(x, 0.05, m).value`
- amplitude proxy: `A = hi - lo`

where the strict interior rule helps avoid choosing points at the very start/end of the analysis window.
