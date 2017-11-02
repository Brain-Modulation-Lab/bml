Matlab functions for ECoG/MER data manipulation and analysis
============================================================
Brain Modulation Laboratory, University of Pittsburgh

This repository provides functions for analysis and manipulation of ECoG, MER 
and Audio data acquired in the Brain Modulation Laboratory (University of Pittsburgh). 
These functions depend on and extend fieldtrip (http://www.fieldtriptoolbox.org/). 
They operate on FT_DATATYPE_RAW data structures and 'annotations tables'. 

Function index:

ANNOT - functions to create and manipulate annotation tables
* bml_annot_consolidate - returns a consolidated annotation table
* bml_annot_plot        - plots an annotation table
* bml_annot_table       - transforms a table into an annotations table [internal]
* bml_annot_intersect   - returns the intersection of two annotation tables
* bml_annot_overlap     - calculates overlapping segments between annotations
* bml_roi_table         - transforms a table into an ROI table [internal]
* bml_synchronize_files - time-aligns files based on a common sync channel

IO - provides input/output functions for file manipulation
* bml_info_file             - returns table with OS info of each file in a folder
* bml_info_raw              - returns table with OS and header info of each raw file in a folder. 
* bml_neuroomega_info_depth - returns a table with .mat file information
* bml_neuroomega_info_file  - returns table with OS info of each neuroomega.mat file in a folder
* bml_neuroomega_info_raw   - returns table with OS and header info of raw neuroomega.mat (.mpx) files.
* bml_neuroomega_load       - loads a NeuroOmega dataset as a struct-array of
* bml_crop_idx              - calculates sample indices for a time window and file coordinates
* bml_idx2time              - calculates samples midpoint times from a index vector and file coordinates
* bml_load_continuous       - loads continuous raw from one or more files
* bml_time2idx              - calculates sample indices from a time vector and file coordinates

SIGNAL - time series manipulation functions
* bml_envelope_binabs  - Calculate envelope as maximum of abssolute value in
* bml_check_contiguity - returns true if raws are time-contiguous
* bml_crop             - returns a time-cropped raw
* bml_hstack           - concatenates multiple raw data structures by time
* bml_pad              - returns a padded version of the raw (crops if necessary)
* bml_timealign        - aligns slave to master and returns the slave's delta t
* bml_timewarp         - aligns and linearly warps slave to master 

UTILS - miscelLaneous utility functions
* bml_date2sec - transforms a cell-array of date strings to seconds from
* bml_praat    - opens FT_DATATYPE_RAWs in praat
* bml_getopt   - gets the value from a configuration structure [internal]




