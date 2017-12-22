% SYNC
%
% Files
%   bml_crop                     - returns a time-cropped raw [INTERNAL]
%   bml_crop_idx                 - calculates sample indices for a time window and file coordinates
%   bml_crop_idx_valid           - calculates valid sample indices for a time window and file coordinates
%   bml_idx2time                 - calculates samples midpoint times from a index vector and file coordinates
%   bml_sync_analog              - time-aligns files based on a common analog sync channel
%   bml_sync_check               - loads files in a synchronization roi table into praat
%   bml_sync_confluence          - is an alias for BML_ROI_CONFLUENCE
%   bml_sync_consolidate         - consolidates file chunks synchronizations

%   bml_time2idx                 - calculates sample indices from a time vector and file coordinates
%   bml_timealign                - aligns slave to master and returns the slave's delta t
%   bml_timewarp                 - aligns and linearly warps slave to master 
%   bml_annot2coord              - gets s1,t1,s2,t2 coordinates from annot and Fs
%   bml_chunk_session            - alias for BML_CHUNK_SESSIONS
%   bml_chunk_sessions           - breaks up sessions into smaller chunks
%   bml_sync_neuroomega_chantype - transfer sync info from one chantype to another
%   bml_sync_neuroomega_event    - synchronizes neuroomega files based on events
%   bml_timealign_annot          - aligns slave to master and returns the slave's delta t
%   bml_timewarp_annot           - is an alias for BML_TIMEALIGN_ANNOT with enforced timewarp

