function annot = bml_annot_union(cfg, x, y)

% BML_ANNOT_UNION returns the union of two annotation tables
%
% Use as
%   annot = bml_annot_union(x)
%   annot = bml_annot_union(x, y);
%   annot = bml_annot_union(cfg, x);
%   annot = bml_annot_union(cfg, x, y);
%
% The first argument cfg is a optional configuration structure, which can contain
% the following optional fields:
%
% cfg.description - string: description for output annotation
% cfg.timetol - float, time tolerance for the union operation. Defaults to
%           1e-3 (1 ms).
% cfg.groupby - string: indicates variable name by which to group the rows
%           before intersecting. Variable has to be present in x and y. If
%           variable names are not the same in both tables, use
%           cfg.grouby_x and cfg.groupby_y.
% cfg.groupby_x - string: 'x' groupby variable name
% cfg.groupby_y - string: 'y' groupby variable name
%
% x, y - annot tables with fields 'starts' and 'ends'.
%
% Returns an annotation table with the format of x, calculated as the union
% of x and y. 


if nargin ==1
	x=bml_annot_table(cfg,[],inputname(1));
  cfg=[];
  y=[];
elseif nargin == 2
  if isstruct(cfg)
    x=bml_annot_table(x,[],inputname(2)); 
    y=[];
    description = ['union_' x.Properties.Description];
  elseif istable(cfg)
    y=bml_annot_table(x,[],inputname(2));
    x=bml_annot_table(cfg,[],inputname(1));
    cfg=[];
    description = ['union_' x.Properties.Description '_' y.Properties.Description];
  else
    error('incorrect use of bml_annot_union');
  end
elseif nargin == 3
  x=bml_annot_table(x,[],inputname(2));
  y=bml_annot_table(y,[],inputname(3));
  description = ['uniont_' x.Properties.Description '_' y.Properties.Description];
  description = bml_getopt(cfg,'description',description);
else
  error('incorrect use of bml_annot_union');
end

timetol   = bml_getopt(cfg,'timetol',1e-3);
groupby   = bml_getopt(cfg,'groupby',[]);
groupby_x = bml_getopt(cfg,'groupby_x',groupby);
groupby_y = bml_getopt(cfg,'groupby_y',groupby);

if isempty(x.Properties.Description); x.Properties.Description = 'x'; end
if ~isempty(y)
  if isempty(y.Properties.Description); y.Properties.Description = 'y'; end

  if strcmp(x.Properties.Description,y.Properties.Description)
    x.Properties.Description = [x.Properties.Description '_x'];
    y.Properties.Description = [y.Properties.Description '_y'];
  end
  
  if ~isempty(groupby_x) && ~isempty(groupby_y) 
    %creating grouping vraible in 'y' table with same name as x
    y.(groupby_x{1}) = y.(groupby_y{1});
  elseif ~(isempty(groupby_x) && isempty(groupby_y))
    error('incorrect call to bml_annot_union');
  end
  
  x = bml_annot_rowbind(x,y);
  
end

cfg1=[];
cfg1.criterion = @(x) abs(max(x.ends) - min(x.starts) - sum(x.duration)) < timetol;
cfg1.groupby = groupby_x;
annot = bml_annot_consolidate(cfg1,x);
annot = bml_annot_table(annot,description);





