# bml
Matlab functions for ECoG/MER data manipulation and analysis
============================================================
Brain Modulation Laboratory, University of Pittsburgh

This repository provides functions for analysis and manipulation of ECoG, MER 
and Audio data acquired in the Brain Modulation Laboratory (University of Pittsburgh). 
These functions depend on and extend fieldtrip (http://www.fieldtriptoolbox.org/). 
They operate on FT_DATATYPE_RAW data structures and 'annotations tables'. 

Function index:

IO - provides input/output functions for file manipulation
* bml_info_file             - returns a table with the information of each file in a
* bml_info_raw              - returns a table with the information of each raw file in a
* bml_neuroomega_info_depth - returns a table with .mat file information
* bml_neuroomega_info_file  - returns a table with the information of each .mat
* bml_neuroomega_info_raw   - returns a table with the information of each raw neuroomega .mat file in a
* bml_neuroomega_load       - loads a NeuroOmega dataset as a struct-array of

SIGNAL - time series manipulation functions
* bml_envelope_binabs - Calculate envelope as maximum of absolute value in

UTILS - miscelLaneous utility functions
* bml_date2sec - transforms a cell-array of date strings to seconds from
* bml_praat    - opens FT_DATATYPE_RAWs in praat




