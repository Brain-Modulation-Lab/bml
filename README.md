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
* bml_event2annot       - creates a annot table from a events structure
* bml_roi_confluence    - expands entries in a roi table to cover all the file
* bml_annot_conform_to  - conforms an annotation table to the shape of an other
* bml_annot_filter      - returns the annots that intersect with of filter
* bml_annot_read        - reads an annotation table
* bml_annot_rowbind     - binds tables by rows, conforming to first table
* bml_annot_transfer    - copies information of transfer to annot
* bml_annot_write       - writes an annotation table
* bml_coding2annot      - creates annot table from CodingMatrix 
* bml_coding2raw        - creates a raw from the audio in the Coding file
* bml_definetrial       - transforms a continuous raw into a trialed raw 
* bml_raw2annot         - creates an annotation table from a raw
* bml_roi2coord         - calculates raw coordinates for entries in roi
* bml_roi_replace_ext   - replaces the extension in a variable

IO - provides input/output functions for file manipulation
* bml_info_file             - returns table with OS info of each file in a folder
* bml_info_raw              - return a annot table with OS and header info of each raw file in a folder. 
* bml_neuroomega_info_depth - returns a table with .mat file information
* bml_neuroomega_info_file  - returns table with OS info of each neuroomega.mat file in a folder
* bml_neuroomega_info_raw   - returns table with OS and header info of raw neuroomega.mat (.mpx) files.
* bml_neuroomega_load       - loads a NeuroOmega dataset as FT_DATATYPE_RAW data structure. 
* bml_load_continuous       - loads continuous raw from one or more files
* bml_read_event            - reads fieldtrip event structures
* bml_read_header           - reads header of a file
* bml_load_epoched          - loads an epoched raw from one or more files

SIGNAL - time series manipulation functions
* bml_envelope_binabs  - Calculate envelope of a signal using the binabs method
* bml_check_contiguity - returns true if raws are time-contiguous
* bml_hstack           - concatenates multiple raw data structures by time
* bml_pad              - returns a padded version of the raw (crops if necessary)
* bml_conform_to       - conforms salve to master
* bml_event2raw        - creates a raw of zeros with ones at event times
* bml_annot2raw        - creates a raw of zeros with ones at annot times
* bml_redefinetrial    - creates new epoching from a raw object

SYNC - time synchronization functions
* bml_crop                     - returns a time-cropped raw [INTERNAL]
* bml_crop_idx                 - calculates sample indices for a time window and file coordinates
* bml_crop_idx_valid           - calculates valid sample indices for a time window and file coordinates
* bml_idx2time                 - calculates samples midpoint times from a index vector and file coordinates
* bml_sync_analog              - time-aligns files based on a common analog sync channel
* bml_sync_check               - loads files in a synchronization roi table into praat
* bml_sync_confluence          - is an alias for BML_ROI_CONFLUENCE
* bml_sync_consolidate         - consolidates file chunks synchronizations
* bml_time2idx                 - calculates sample indices from a time vector and file coordinates
* bml_timealign                - aligns slave to master and returns the slave's delta t
* bml_timewarp                 - aligns and linearly warps slave to master 
* bml_annot2coord              - gets s1,t1,s2,t2 coordinates from annot and Fs
* bml_chunk_session            - alias for BML_CHUNK_SESSIONS
* bml_chunk_sessions           - breaks up sessions into smaller chunks
* bml_sync_neuroomega_chantype - transfer sync info from one chantype to another
* bml_sync_neuroomega_event    - synchronizes neuroomega files based on events
* bml_timealign_annot          - aligns slave to master and returns the slave's delta t
* bml_timewarp_annot           - is an alias for BML_TIMEALIGN_ANNOT with enforced timewarp

UTILS - miscelLaneous utility functions
* bml_date2sec      - transforms a cell-array of date strings to seconds from
* bml_praat         - opens FT_DATATYPE_RAWs in praat
* bml_getopt        - gets the value from a configuration structure [internal]
* bml_getopt_single - gets a single value from a configuration structure [internal]
* bml_raw2coord     - returns the time coordinated of the raw
* bml_get_idx       - BML_GET_INDEX gets the first indices of the elements in the domain
* bml_map           - maps elements based on given domain and codomain




