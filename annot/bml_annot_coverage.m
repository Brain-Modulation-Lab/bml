function coverage = bml_annot_coverage(cfg, x, y)

% BML_ANNOT_COVERAGE calculates the fraction of denominator (y) covered by
% numerator (x)
%
% Use as
%   coverage = bml_annot_coverage(cfg, x, y);
%   coverage = bml_annot_coverage(x, y);
%
% The first argument cfg is a optional configuration structure with
% the following optional fields:
%
% cfg.groupby - grouping variable assigned to numerator, and also to denominator 
%   if colname is present.
% cfg.groupby_x - cellstr indicating grouping columns of x (numerator). If empty
%   (default), all rows of x are considered in the same group. 
% cfg.groupby_y - cellstr indicating grouping columns of y (denominator). If empty
%   (default), all rows of y are considered for all groups of x.
%
% x, y - annot tables with fields 'starts' and 'ends'.
%
% Returns an annotation table with the same variables as 'y' plus
% and additional coverage variable. If groupby is given, each row of 
% y is expanded into a group of size given by the number of levels of
% groupby. The grouping variable of x is included in coverage. 

if nargin == 2
  y = x;
  x = cfg;
  cfg = [];
elseif nargin ~= 3
  error('incorrect use of bml_annot_coverage. See help.');
end

groupby             = bml_getopt(cfg,'groupby',[]);
groupby_x   =  bml_getopt(cfg,'groupby_numerator',groupby);
groupby_y =  bml_getopt(cfg,'groupby_denominator',...
                intersect(groupby, y.Properties.VariableNames));

%ToDo: allow grouping by several variables
if isempty(groupby_y)
  group_y = false;
  if isempty(groupby_x)
    x.groupby_ = ones(height(x),1);
    groupby_x = {'groupby_'};
    groups={1};
  else
    if sum(strcmp(x.Properties.VariableNames, groupby_x))~=1
      error('groupby should match one (and only one) column of numerator');
    end
    groups = unique(x{:,groupby_x});
  end
else
  if sum(strcmp(y.Properties.VariableNames, groupby_y))~=1
    error('groupby should match one (and only one) column of y (denominator)');
  end
  group_y = true;
  groups = unique(y{:,groupby_y});  
	if isempty(groupby_x)
    error("can't group only by y")
  else
    if sum(strcmp(x.Properties.VariableNames, groupby_x))~=1
      error('groupby should match one (and only one) column of numerator');
    end
  end
end

coverage = cell(numel(groups) .* height(y) ,width(y) + 2);
idx=1;
width_y = width(y);
for g=1:numel(groups)
  if iscellstr(groups(g))
    x_g = x(strcmp(x{:,groupby_x},groups(g)),:);
    if group_y
      y_g = y(strcmp(y{:,groupby_y},groups(g)),:);
    else
      y_g=y;
    end
  else
    x_g = x(x{:,groupby_x}==groups{g},:);    
    if group_y
      y_g = y(y{:,groupby_y}==groups{g},:);
    else
      y_g=y;
    end
  end
  if ~isempty(x_g)
    x_g = sortrows(x_g,'starts');
    for j=1:height(y_g)
      i=1;
      t=y_g.starts(j);
      cvg=0;
      while i <= height(x_g) && t < y_g.ends(j)
        if x_g.starts(i) < y_g.ends(j) && x_g.ends(i) > t
            s=max(x_g.starts(i),t);
            e=min(x_g.ends(i),y_g.ends(j));
            cvg=cvg+e-s;
            t=e;
          if e < y_g.ends(j)
            i = i + 1;
          end
        elseif x_g.ends(i) <= y_g.starts(j)
          i=i+1;
        elseif x_g.starts(i) >= y_g.ends(j)
          break
        else
          error('error in bml_annot_coverage');
        end
      end
      coverage(idx,1:width_y) = table2cell(y_g(j,1:width_y));
      coverage(idx,width_y+1) = groups(g);
      coverage{idx,width_y+2} = cvg/y_g.duration(j);
      idx=idx+1;
    end
  else %x_g is empty
    coverage(idx:(idx+height(y_g)-1),1:width_y) = table2cell(y_g(:,1:width_y));
    coverage(idx:(idx+height(y_g)-1),width_y+1) = groups(g);
    coverage(idx:(idx+height(y_g)-1),width_y+2) = {0};
    idx=idx+height(y_g);  
  end
end

coverage = cell2table(coverage);
coverage.Properties.VariableNames = [y.Properties.VariableNames,groupby_x,'coverage'];

if any(strcmp('groupby_',coverage.Properties.VariableNames))
  coverage.groupby_ = [];
end

coverage.id=[];
coverage = bml_annot_table(coverage);



