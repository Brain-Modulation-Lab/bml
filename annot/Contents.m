% ANNOT
%
% Files
%   bml_annot_consolidate - returns a consolidated annotation table
%   bml_annot_plot        - plots an annotation table
%   bml_annot_table       - transforms a table into an annotations table [internal]
%   bml_annot_intersect   - returns the intersection of two annotation tables
%   bml_annot_overlap     - calculates overlapping segments between annotations
%   bml_roi_table         - transforms a table into an ROI table [internal]
%   bml_annot_detect      - identifies annotations thresholding an envelope signal
%   bml_annot_extend      - extends the annotation times
%   bml_annot_shadow      - creates annotations that 'shadow' the ones in annot
%   bml_annot_t0          - changes the time reference of an annot table

%   bml_event2annot       - creates a annot table from a events structure
%   bml_roi_confluence    - expands entries in a roi table to cover all the file


%   bml_annot_conform_to  - conforms an annotation table to the shape of an other
%   bml_annot_filter      - returns the annots that intersect with of filter
%   bml_annot_read        - reads an annotation table
%   bml_annot_rowbind     - binds tables by rows, conforming to first table
%   bml_annot_transfer    - copies information of transfer to annot
%   bml_annot_write       - writes an annotation table
%   bml_coding2annot      - creates annot table from CodingMatrix 
%   bml_coding2raw        - creates a raw from the audio in the Coding file
%   bml_definetrial       - transforms a continuous raw into a trialed raw 
%   bml_raw2annot         - creates an annotation table from a raw
%   bml_roi2coord         - calculates raw coordinates for entries in roi
%   bml_roi_replace_ext   - replaces the extension in a variable

