# System Overview and Data Flow

## The synchronization pipeline

```{mermaid}
flowchart TD
    subgraph Build["Build ROI"]
        A[Raw files on disk] --> B[bml_info_raw]
        B --> C[bml_roi_table\ndefault s1,t1,s2,t2]
        C --> D[bml_chunk_sessions\nsplit into windows]
    end

    subgraph Analog["Analog Sync — Zoom"]
        E[bml_sync_analog] --> F[bml_timewarp\nenvelope ±300 s]
        F --> G[bml_timewarp\nLPF ±1 s]
        G --> H[sync_roi_analog]
    end

    subgraph Events["Event Sync"]
        I[bml_read_event\nmaster TTL events] --> J[bml_sync_neuroomega_event]
        I --> K[bml_sync_digital\nPsychotoolbox]
        J --> L[sync_roi_events]
        K --> L
    end

    subgraph Cons["Consolidation"]
        M[bml_sync_consolidate\nLevel 1: per-file polyfit\nLevel 2: contiguous files]
        N[Final sync_roi\n1 row/file · <1ms residual]
    end

    C --> Analog
    D --> Analog
    C --> Events
    H --> M
    L --> M
    M --> N
    N --> O[bml_idx2time / bml_time2idx\nAll analysis in master time]
```

## Three-stage pipeline

| Stage | What happens | Key function |
|-------|-------------|--------------|
| **Build** | Scan disk, create ROI with default OS-timestamp coordinates | `bml_roi_table`, `bml_chunk_sessions` |
| **Sync** | Compute `delta_t` and `warpfactor` per chunk | `bml_sync_analog`, `bml_sync_neuroomega_event`, `bml_sync_digital` |
| **Consolidate** | Merge multi-chunk estimates into one row per file, validate residuals | `bml_sync_consolidate` |

## Chunking

Long sessions are split into independent time windows for sync estimation. The `bml_chunk_sessions` call controls this:

```matlab
session = bml_annot_table(table(52310, 52610, 'VariableNames',{'starts','ends'}));

% Split into 3 equal chunks
chunks = bml_chunk_sessions(session, 3);

% Split at a specific time
chunks = bml_chunk_sessions(session, 52450);

% Split into windows of fixed duration
chunks = bml_chunk_sessions(session, [], 100);  % 100-second windows
```

Recommended chunk duration: **60–100 s**. Shorter chunks give noisier estimates; longer chunks miss local drift changes.
