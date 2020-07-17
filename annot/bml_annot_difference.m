function annot = bml_annot_difference(cfg, x, y)

% BML_ANNOT_DIFFERENCE returns the difference of two annotation tables
%
% Use as
%   annot = bml_annot_difference(x, y);
%   annot = bml_annot_difference(cfg, x, y);
%
% The first argument cfg is a optional configuration structure, which can contain
% the following optional fields:
%
% cfg.description - string: description of output annotation
% cfg.groupby - string: indicates variable name by which to group the rows
%           before calculating the difference. Variable has to be present in x and y. If
%           variable names are not the same in both tables, use
%           cfg.grouby_x and cfg.groupby_y.
% cfg.groupby_x - string: 'x' groupby variable name
% cfg.groupby_y - string: 'y' groupby variable anme
%
% x, y - annot tables with fields 'starts' and 'ends'.
%
% Returns an annotation table with the variables of x, with modified 

if nargin == 2
  y=bml_annot_table(x,[],inputname(2));
  x=bml_annot_table(cfg,[],inputname(1));
  cfg=[];
elseif nargin == 3
  x=bml_annot_table(x,[],inputname(2));
  y=bml_annot_table(y,[],inputname(3));
else
  error('use as bml_annot_difference(x, y)')
end

if isempty(x) || isempty(y)
  annot=x;
  return
end

if isempty(x.Properties.Description); x.Properties.Description = 'x'; end
if isempty(y.Properties.Description); y.Properties.Description = 'y'; end
if strcmp(x.Properties.Description,y.Properties.Description)
  x.Properties.Description = [x.Properties.Description '_x'];
  y.Properties.Description = [y.Properties.Description '_y'];
end
description = ['diff_' x.Properties.Description '_' y.Properties.Description];
description = ft_getopt(cfg,'description',description);

groupby   = bml_getopt(cfg,'groupby',[]);
groupby_x = bml_getopt(cfg,'groupby_x',groupby);
groupby_y = bml_getopt(cfg,'groupby_y',groupby);

%ToDo: allow grouping by several variables
if isempty(groupby_x) && isempty(groupby_y)
  x.groupby_=ones(height(x),1);
  y.groupby_=ones(height(y),1);
  groupby_x = {'groupby_'};
  groupby_y = {'groupby_'};
  groups_x={1};
elseif ~isempty(groupby_x) && ~isempty(groupby_y)
	if sum(strcmp(x.Properties.VariableNames, groupby_x))~=1
    error('groupby_x should match one (and only one) column of x');
  end
	if sum(strcmp(y.Properties.VariableNames, groupby_y))~=1
    error('groupby_y should match one (and only one) column of y');
  end
  groups_x = unique(x{:,groupby_x});
  groups_y = unique(y{:,groupby_y});
  groups = intersect(groups_x,groups_y);
  if isempty(groups) %nothing to substract
    annot = x;
    annot.Properties.Description = description;
    return
  end
else
  error('groupby_x and groupby_y should be both given or none at all')
end

annot =table();
for g=1:numel(groups_x)
  annot_g=table();
  if iscellstr(groups_x(g))
    x_g = x(strcmp(x{:,groupby_x},groups_x(g)),:);
    y_g = y(strcmp(y{:,groupby_y},groups_x(g)),:);
  else
    x_g = x(x{:,groupby_x}==groups_x{g},:);   
    y_g = y(y{:,groupby_y}==groups_x{g},:);   
  end
  if height(y_g) > 0
    i=1; j=1;
    while i<=height(x_g) && j<=height(y_g)
      x_start = x_g.starts(i);
      x_end   = x_g.ends(i);
      x_id    = x_g.id(i);
      y_start = y_g.starts(j);
      y_end   = y_g.ends(j);

      if y_start <= x_start && x_start < x_end && x_end <= y_end
        %     xxxxxxxxxxxx
        %  yyyyyyyyyyyyyyyyyy
        i=i+1;
      elseif x_start < y_start && y_start < y_end && y_end < x_end
        %     xxxxxxxxxxxx
        %        yyyyy  
        annot_g = [annot_g;{x_start,y_start,x_id,groups_x(g)}];
        x_g.starts(i)=y_end; 
        j=j+1;
      elseif x_start < y_start && y_start < x_end && x_end <= y_end
        %     xxxxxxxxxxxx
        %         yyyyyyyyyyyy
        annot_g = [annot_g;{x_start,y_start,x_id,groups_x(g)}];
        i=i+1;
      elseif y_start <= x_start && x_start < y_end && y_end < x_end
        %     xxxxxxxxxxxx
        % yyyyyyyyy
        x_g.starts(i)=y_end;   
        j=j+1;
      elseif x_end <= y_start 
        %    xxxxxxxxxxxxx
        %                    yyyyyyyy
        annot_g = [annot_g;{x_start,x_end,x_id,groups_x(g)}];  
        i=i+1;
      elseif y_end <= x_start
        %       xxxxxxxxxxx
        % yyyy   
        j=j+1;
        if j>height(y_g)
        	annot_g = [annot_g;{x_start,x_end,x_id,groups_x(g)}];         
        end
      else
          error('Should never get here. Is there any annotation with negative duration?');
      end
    end
    if ~isempty(annot_g)
      annot_g.Properties.VariableNames = {'starts','ends','id',groupby_x{1}}; 
    end
  else
    annot_g = x_g(:,{'starts','ends','id',groupby_x{1}});
  end
  annot = [annot; annot_g];
end
if isempty(annot); return; end
annot.Properties.VariableNames = {'starts','ends','x_id_',groupby_x{1}};
annot = bml_annot_table(annot,description);
if isempty(annot); return; end

x.x_id_ = x.id;
x.starts=[]; x.ends=[]; 
x.id=[]; x.duration=[];
x.(groupby_x{1})=[];

annot = join(annot,x,'keys','x_id_');

if any(strcmp('groupby_',annot.Properties.VariableNames))
  annot.groupby_ = [];
end



