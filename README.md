Matlab functions for ECoG/MER data manipulation and analysis
============================================================
Brain Modulation Laboratory, University of Pittsburgh

This repository provides functions for analysis and manipulation of ECoG, MER 
and Audio data acquired in the Brain Modulation Laboratory (University of Pittsburgh). 
These functions depend on, and extend, fieldtrip (http://www.fieldtriptoolbox.org/). 
They operate on FT_DATATYPE_RAW data structures and 'annotations tables'. 

Function index:

ANNOT - functions to create and manipulate annotation tables
* bml_annot_consolidate - returns a consolidated annotation table
* bml_annot_plot        - plots an annotation table
* bml_annot_table       - transforms a table into an annotations table [internal]
* bml_annot_intersect   - returns the intersection of two annotation tables
* bml_annot_overlap     - calculates overlapping segments between annotations
* bml_roi_table         - transforms a table into an ROI table [internal]
* bml_annot_detect      - identifies annotations thresholding an envelope signal
* bml_annot_extend      - extends the annotation times
* bml_annot_shadow      - creates annotations that 'shadow' the ones in annot
* bml_annot_t0          - changes the time reference of an annot table
* bml_chunk_sessions    - breaks up sessions into smaller chunks
* bml_event2annot       - creates a annot table from a events structure
* bml_roi_confluence    - expands entries in a roi table to cover all the file

IO - provides input/output functions for file manipulation
* bml_info_file             - returns table with OS info of each file in a folder
* bml_info_raw              - return a annot table with OS and header info of each raw file in a folder. 
* bml_neuroomega_info_depth - returns a table with .mat file information
* bml_neuroomega_info_file  - returns table with OS info of each neuroomega.mat file in a folder
* bml_neuroomega_info_raw   - returns table with OS and header info of raw neuroomega.mat (.mpx) files.
* bml_neuroomega_load       - loads a NeuroOmega dataset as FT_DATATYPE_RAW data structure. 
* bml_load_continuous       - loads continuous raw from one or more files
* bml_read_event            - BML_READ_EVENT
* bml_read_header           - BML_READ_HEADER

SIGNAL - time series manipulation functions
* bml_envelope_binabs  - Calculate envelope as maximum of abssolute value in
* bml_check_contiguity - returns true if raws are time-contiguous
* bml_hstack           - concatenates multiple raw data structures by time
* bml_pad              - returns a padded version of the raw (crops if necessary)
* bml_conform_to       - conforms salve to master
* bml_event2raw        - creates a raw of zeros with ones at event times

SYNC - time synchronization functions
* bml_crop             - returns a time-cropped raw
* bml_crop_idx         - calculates sample indices for a time window and file coordinates
* bml_crop_idx_valid   - calculates valid sample indices for a time window and file coordinates
* bml_idx2time         - calculates samples midpoint times from a index vector and file coordinates
* bml_sync_analog      - time-aligns files based on a common analog sync channel
* bml_sync_check       - loads files in a synchronization roi table into praat
* bml_sync_confluence  - is an alias for BML_ROI_CONFLUENCE
* bml_sync_consolidate - consolidates file chunks synchronizations
* bml_sync_digital     - BML_SYNC_digital time-aligns files based on a common digital sync channel
* bml_time2idx         - calculates sample indices from a time vector and file coordinates
* bml_timealign        - aligns slave to master and returns the slave's delta t
* bml_timewarp         - aligns and linearly warps slave to master 

UTILS - miscelLaneous utility functions
* bml_date2sec      - transforms a cell-array of date strings to seconds from
* bml_praat         - opens FT_DATATYPE_RAWs in praat
* bml_getopt        - gets the value from a configuration structure [internal]
* bml_getopt_single - gets a single value from a configuration structure [internal]
* bml_raw2coord     - BMLRAW2COORD returns the time coordinated of the raw




