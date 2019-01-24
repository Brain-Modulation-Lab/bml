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
% cfg.comment_position = [x,y] float, with x and y position for the legent
%                   in the [0,1] range. Also can be one of "center", "left", "right",
%                   "bottom", "top"
% cfg.rotate      = float, degrees by which to rotate the layout
% cfg.center      = [x,y] coord of center for rotation. Defaults to [0,0]
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
comment_position = bml_getopt(cfg,'comment_position');
rotate        = bml_getopt(cfg,'rotate',0);
center        = bml_getopt(cfg,'center',[0,0]);

assert(size(center,1)==1 && size(center,2)==2, 'center should be a 1x2 float')

lay = ft_prepare_layout(cfg);
   
%checking for regular layout 
isel = ~(ismember(lay.label,{'COMNT','SCALE'}));
ux = unique(lay.pos(isel,1));
uy = unique(lay.pos(isel,2));  
nx = length(ux);
ny = length(uy);

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

if strcmp(tight,'yes')
  if length(uxdiff)>1 || length(uydiff)>1
    warning('irregular layout in %s', cfg.layout);
  end
  
  lay.width = lay.width*uxdiff(1)*(1-x_space);
  lay.height = lay.height*uydiff(1)*(1-y_space);      
end

uw = unique(lay.width);
uh = unique(lay.height);
x0 = min(ux);
x1 = max(ux);
y0 = min(uy);
y1 = max(uy);

if abs(mod(rotate,360))>1
  %rotating

  r = rotate * pi/180;
  rM = [cos(r), -sin(r); sin(r), cos(r)];
  rpos = (rM * (lay.pos(isel,:) - center)')' + center;
  lay.pos(isel,:) = round(rpos, -(ceil(log10(max(max(rpos,[],1),[],2)))-5));
end

if ~isempty(comment_position)
	k = find(strcmp('COMNT', lay.label));  
  
  
  if isnumeric(comment_position)
    lay.pos(k, 1) = (x1-x0) * comment_position(1) + x0;
    lay.pos(k, 2) = (y1-y0) * comment_position(2) + y0;   
  else
    switch comment_position{1}
      case 'left'
        lay.pos(k, 1) = x0 - 0.75*uw(1);
        lay.pos(k, 2) = (y1+y0)/2; 
      case 'right'
        lay.pos(k, 1) = x1 + 0.75*uw(1);
        lay.pos(k, 2) = (y1+y0)/2; 
      case 'bottom'
        lay.pos(k, 1) = (x0+x1)/2;
        lay.pos(k, 2) = y0 - 0.75*uh(1);     
      case 'top'        
        lay.pos(k, 1) = (x0+x1)/2;
        lay.pos(k, 2) = y1 + 0.75*uh(1);   
      case 'center'
        lay.pos(k, 1) = (x0+x1)/2;
        lay.pos(k, 2) = (y1+y0)/2;   
    end
  end
end











