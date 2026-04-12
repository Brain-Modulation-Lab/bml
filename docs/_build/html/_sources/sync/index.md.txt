# Synchronization Pipeline

BML recordings involve up to four independent devices, each running its own clock. The synchronization pipeline maps every slave device's timestamps onto the **Trellis/Ripple master clock**.

## Devices

| Device | Role | Clock error | Sync method |
|--------|------|------------|-------------|
| Ripple/Trellis NSP | **Master** | Reference | — |
| Zoom audio recorder | Slave | Offset + drift | Analog xcorr **or** digital peaks |
| NeuroOmega (Alpha Omega) | Slave | Offset + drift | Shared TTL events |
| Task laptop (Psychtoolbox) | Slave | Hours offset, low drift | DP event matching + fallback |

## Two types of clock error

$$t_{\text{master}} = \delta t + \xi \cdot t_{\text{slave}}$$

- **Offset** $\delta t$: constant shift (seconds to hours). Corrected by `delta_t`.
- **Drift** $\xi$: clock rate difference (1–10 ppm). Corrected by `warpfactor = 1/ws1`.

## Contents

```{toctree}
:maxdepth: 1

overview
audio
neuroomega
psychtoolbox
dp_matching
consolidation
best_practices
```
