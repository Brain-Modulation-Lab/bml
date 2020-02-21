function anat_labels = bml_anat_label_coord(cfg, coord)

% BML_ANAT_LABEL_COORD returns a label from an atlas corresponding to a
% given coordinate
%
% Use as
%   anat_labels = bml_anat_label_coord(cfg, coord);
%
% The first argument cfg is a configuration structure, which can contain
% the following fields:
% cfg.atlas - name of the atlas to use 
% cfg.max_assign - integer >= 1, max number of labels assigned to each electrode. Defaults to 1. 
% cfg.radius - radius in mm around each electrode coordinate to consider in
%        label assignation. 
% cfg.profile - either 'sphere' or 'gaussian'
% cfg.atlas_path - path to volume atlas repository. Defaults to lead-dbs's
%             icbm 2009b nlin asym labeling folder
% cfg.keys - table with code to structure key. By default the .txt file 
%             associated with the nifti file is used 
% cfg.exclude_labels - vector with integer labels to exclude. Defaults yto
%             [0], normally assigned to CSF
% cfg.label_column_basename - string. Basename for added columns to coord with
%             label information. Defauls to first part of atlas name. 
%
% coord - table with electrode coordinates. The first three columns ending 
% with  _x, _y, _z will be used as x,y,z coordinates. Note that the coordinates have to be
% in the same space as the atlas. Normally this is going to be in mni space
% (template: MNI152 ICBM NLIN ASYM 2009b, frame: RAS AC). 
%
% Returns a table with labels for each electrode according to the
% atlas. If max_labels > 1, that number of columns are added with all
% assigned labels, by order of coverage. 

if ~exist('ea_space','file'); error('leaddbs toolbox required in path'); end

atlas_path     = bml_getopt_single(cfg,'atlas_path',ea_space([], 'labeling'));
atlas          = bml_getopt_single(cfg,'atlas','AICHA (Joliot 2015)');
keys           = bml_getopt_single(cfg,'keys',atlas);
max_assign     = bml_getopt(cfg,'max_assign',1);
sigma          = bml_getopt(cfg,'sigma',1);
radius         = bml_getopt(cfg,'radius',3);
profile        = bml_getopt_single(cfg,'profile','gaussian');
exclude_labels = bml_getopt(cfg,'exclude_labels',0);
lab_col_bn = strsplit(atlas,' ');
if iscell(lab_col_bn); lab_col_bn = lab_col_bn{1}; end
lab_col_bn = bml_getopt_single(cfg,'label_column_basename',lab_col_bn);

%getting coordinates
if ~istable(coord); error('coord should be table'); end
col_idx_x = find(endsWith(coord.Properties.VariableNames,'_x'),1);
col_idx_y = find(endsWith(coord.Properties.VariableNames,'_y'),1);
col_idx_z = find(endsWith(coord.Properties.VariableNames,'_z'),1);
if isempty(col_idx_x) || isempty(col_idx_y) || isempty(col_idx_z)
    error('_x _y and _z columns required');
end
XYZ_mm = [coord{:,col_idx_x}, coord{:,col_idx_y}, coord{:,col_idx_z}];
XYZ_mm = [XYZ_mm ones(size(XYZ_mm,1),1)];

%initializing columns
if max_assign == 1
    if ismember(lab_col_bn,coord.Properties.VariableNames)
        fprintf('recalculating %s \n',lab_col_bn)
        coord(:,lab_col_bn) = NaN(height(coord),1);
    else
        coord = addvars(coord, NaN(height(coord),1),'NewVariableNames',lab_col_bn);        
    end
elseif max_assign > 1
    for i=1:max_assign       
        col_Li = [lab_col_bn '_l' num2str(i)];
        col_Wi = [lab_col_bn '_w' num2str(i)];
        if ismember(col_Li,coord.Properties.VariableNames)
            fprintf('recalculating %s \n',col_Li)
            coord(:,col_Li) = repmat({''},height(coord),1);
        else
        	coord = addvars(coord, repmat({''},height(coord),1),'NewVariableNames',col_Li);             
        end
        
        if ismember(col_Wi,coord.Properties.VariableNames)
            fprintf('recalculating %s \n',col_Wi)
            coord(:,col_Wi) = NaN(height(coord),1);
        else
        	coord = addvars(coord, NaN(height(coord),1),'NewVariableNames',col_Wi);             
        end
    end
end

%getting labels nifti
fname_nii = [atlas_path atlas '.nii'];
if ~isfile(fname_nii); error('atlas nifti file not found at %s',fname_nii); end
nii=ea_load_nii(fname_nii);
vx2mm = ea_get_affine(fname_nii);

%getting labels keys
if ~istable(keys)
    fname_txt = [atlas_path keys '.txt'];
    if ~isfile(fname_txt); error('atlas keys file not found at %s',fname_txt); end
    keys = readtable(fname_txt,'Format','%d %s','ReadVariableNames',false,'TextType','char');
    keys.Properties.VariableNames = {'id','label'};
end
    
%definig built-in profile functions
if ischar(profile)
    if strcmp(profile,'sphere')
        profile = @(v) norm(v)<=radius;
    elseif strcmp(profile,'gaussian')
        profile = @(v) exp(-(norm(v)^2)/(2*sigma^2));
    else
        error('profile should be a ''sphere'', ''gaussian'' or a function hadle')
    end
elseif isa(profile,'function_handle')
    
else
    error('profile should be a ''sphere'', ''gaussian'' or a function hadle')
end

% Row Column and Slice versors in real world coords
vR=vx2mm(1:3,1:3)*[1;0;0]; n_vR = norm(vR);
vC=vx2mm(1:3,1:3)*[0;1;0]; n_vC = norm(vC);
vS=vx2mm(1:3,1:3)*[0;0;1]; n_vS = norm(vS);

%box 'radii'
radius_R = ceil(radius./n_vR);
radius_C = ceil(radius./n_vC);
radius_S = ceil(radius./n_vS);

%label assignation
RCS_vx=(vx2mm\XYZ_mm')';
for e=1:size(RCS_vx,1) %for each electrode
    vx_precise = RCS_vx(e,1:3);
    vx = round(vx_precise);
    if ~any(ismissing(vx))
        range_R = max(1,vx(1)-radius_R):min(nii.dim(1),vx(1)+radius_R);
        range_C = max(1,vx(2)-radius_C):min(nii.dim(2),vx(2)+radius_C);
        range_S = max(1,vx(3)-radius_S):min(nii.dim(3),vx(3)+radius_S);
        
        % creating weighting cube based on precise voxel coords to avoid
        % rounding error
        w_cube = zeros(length(range_R),length(range_C),length(range_S));
        for i=1:length(range_R)
            for j=1:length(range_C)
                for k=1:length(range_S)
                    r_prime = [range_R(i),range_C(j),range_S(k)] - vx_precise; 
                    w_cube(i,j,k)=profile(vx2mm(1:3,1:3)*(r_prime)');
                end 
            end
        end
        w_cube = w_cube./sum(w_cube,'all');
        
        % calculating weights for each label
        labs = unique(round(nii.img(range_R,range_C,range_S)));
        labs = setdiff(labs, exclude_labels);
        w = zeros(length(labs),1);
        for l=1:length(labs)
            w(l) = sum(w_cube .* (round(nii.img(range_R,range_C,range_S)) == labs(l)),'all');
        end
        
        [w, sort_idx] = sort(w,'descend');
        labs = labs(sort_idx);
        labs = labs(w > eps);
        w = w(w > eps);
        
        labs = bml_map(labs,keys.id,keys.label);
        
        if ~isempty(labs)
            if max_assign == 1
               coord(e,lab_col_bn)=labs(1);
            elseif max_assign > 1
                for i=1:min(max_assign,length(labs))
                    coord(e,[lab_col_bn '_l' num2str(i)])=labs(i);
                    coord{e,[lab_col_bn '_w' num2str(i)]}=w(i);      
                end
            end
        end
        
    end
    
    anat_labels = coord;
end


