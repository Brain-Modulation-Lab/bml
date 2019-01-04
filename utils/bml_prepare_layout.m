function [lay,nx,ny] = bml_prepare_layout(cfg)

% BML_PREPARE_LAYOUT is a wrapper over ft_prepare_layout
%
% Use as
%   lay = bml_prepare_layout(cfg)
%   lay = bml_prepare_layout(cfg.layout)
%   [lay,nx,ny] = bml_prepare_layout(___)
%
% cfg.configuration structure to pass to ft_prepare_layout
% cfg.layout      = filename containg the input layout (*.lay file)
% cfg.skipscale   = 'yes' or 'no', whether the scale should be included in the layout or not (default = 'yes')
% cfg.outline     = string, how to create the outline, can be 'circle', 'convex', 'headshape', 'mri' or 'no' (default is 'no')
% cfg.mask        = string, how to create the mask, can be 'circle', 'convex', 'headshape', 'mri' or 'no' (default is 'no')
% cfg.tight       = 'yes' or 'no', whether the width and height should be
%                   modified to achieve a tight layout when plotting.
%                   Dafaults to 'yes'. 
% cfg.x_space     = float, fractional separation in x direction. Defaults to 0.02.
% cfg.y_space     = float, fractional separation in y direction. Defaults to 0.02
% cfg.comment_position = [x,y] float, with x and y in [0,1]
%
% returns a layout object lay, and the amount of colums (nx) and rows (ny)
% of the layout

if ~isstruct(cfg)
  cfg=struct('layout',cfg);
end

cfg.skipscale = bml_getopt_single(cfg,'skipscale','yes');
cfg.outline   = bml_getopt_single(cfg,'outline','no');
cfg.mask      = bml_getopt_single(cfg,'mask','no');
tight         = bml_getopt(cfg,'tight','yes');
x_space       = bml_getopt(cfg,'x_space',0.02);
y_space       = bml_getopt(cfg,'y_space',0.02);
comment_position = bml_getopt(cfg,'comment_position',[]);


lay = ft_prepare_layout(cfg);
   
%checking for regular layout 
ux = unique(lay.pos(1:(end-2),1));
uy = unique(lay.pos(1:(end-2),2));  
nx = length(ux);
ny = length(uy);

if strcmp(tight,'yes')
  
  if length(uy)>1
    uydiff = unique(diff(uy)); 
  else
    uydiff = 1;
  end
  if length(ux)>1
    uxdiff = unique(diff(ux));
  else
    uxdiff = uydiff;
  end

  if length(uxdiff)>1 || length(uydiff)>1
    warning('irregular layout in %s', cfg.layout);
  end
  
  lay.width = lay.width*uxdiff(1)*(1-x_space);
  lay.height = lay.height*uydiff(1)*(1-y_space);      

end

if ~isempty(comment_position)
	k = find(strcmp('COMNT', lay.label));
  lay.pos(k, 1) = (max(ux)-min(ux)) * comment_position(1) + min(ux);
  lay.pos(k, 2) = (max(uy)-min(uy)) * comment_position(2) + min(uy);  
end












