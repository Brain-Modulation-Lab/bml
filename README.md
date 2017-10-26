# bml
Matlab functions for ECoG/MER data manipulation and analysis
============================================================

Brain Modulation Laboratory, University of Pittsburgh
-----------------------------------------------------

This repository provides functions for analysis and manipulation of ECoG, MER 
and Audio data acquired in the Brain Modulation Laboratory (University of Pittsburgh). 
These functions depend on and extend fieldtrip (http://www.fieldtriptoolbox.org/). 
They operate on FT_DATATYPE_RAW data structures and 'annotations tables'. 

Function index:

ANNOT
...bml_annot_consolidate  - returns a consolidated annotation table
...bml_annot_plot         - plots an annotation table
...bml_annot_reorder_vars - changes the order of vars in an annot table
...bml_annot_table        - transforms a table into an annotations table

IO - provides input/output functions for file manipulation
...bml_info_file             - returns table with OS info of each file in a folder
...bml_info_raw              - returns table with OS and header info of each raw file in a folder. 
...bml_neuroomega_info_depth - returns a table with .mat file information
...bml_neuroomega_info_file  - returns table with OS info of each neuroomega.mat file in a folder
...bml_neuroomega_info_raw   - returns table with OS and header info of raw neuroomega.mat (.mpx) files.
...bml_neuroomega_load       - loads a NeuroOmega dataset as a struct-array of

SIGNAL - time series manipulation functions
...bml_envelope_binabs - Calculate envelope as maximum of abssolute value in

UTILS - miscelaneous utility functions
...bml_date2sec - transforms a cell-array of date strings to seconds from
...bml_praat    - opens FT_DATATYPE_RAWs in praat




