function anat_labels = bml_anat_label_coord(cfg, coord)

% BML_ANAT_LABEL_COORD returns a label from an atlas corresponding to a
% given coordinate
%
% Use as
%   anat_labels = bml_anat_label_coord(cfg, coord);
%
% The first argument cfg is a configuration structure, which can contain
% the following field:
% cfg.atlas - name of the atlas to use 
% cfg.max_distance - maximal distance of point to volume region with
%             allowed label
% cfg.atlas_path - path to volume atlas repository. Defaults to lead-dbs's
%             icbm 2009b nlin asym labeling folder
% cfg.keys - table with code to structure key. By default the .txt file 
%             associated with the nifti file is used 
%
% coord - table with electroed coordinates. 3 column table exapected,
% corresponding to x,y,z coordinates. Note that the coordinates have to be
% in the same space as the atlas. Normally this is going to be in mni space
% (template: MNI152 ICBM NLIN ASYM 2009b, frame: RAS AC). 
%
% Returns a cell array with labels for each electrode according to the
% atlas


atlas_path     = bml_getopt(cfg,'atlas_path',ea_space([], 'labeling'));




