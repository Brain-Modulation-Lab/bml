function annot = bml_annot_intersect(cfg, x, y)

% BML_ANNOT_INTERSECT returns the intersection of two annotation tables
%
% Use as
%   annot = bml_annot_intersect(x, y);
%   annot = bml_annot_intersect(cfg, x, y);
%   annot = bml_annot_intersect(cfg.keep, x, y);
%
% The first argument cfg is a optional configuration structure, which can contain
% the following optional fields:
%
% cfg.keep - string: 'x','y','none' or 'both'. Indicates which variables to keep
%                         if 'both' (default), shared variable names are prefixed
%                         with the table's description. 
% cfg.description - string: description of output annotation
% cfg.warn - logical: indicates if warnings should be issue if variables
%           are overwriten
% cfg.groupby - string: indicates variable name by which to group the rows
%           before intersecting. Variable has to be present in x and y. If
%           variable names are not the same in both tables, use
%           cfg.grouby_x and cfg.groupby_y.
% cfg.groupby_x - string: 'x' groupby variable name
% cfg.groupby_y - string: 'y' groupby variable anme
%
% x, y - annot tables with fields 'starts' and 'ends'.
%        'y' should have no overlapping annotations 
%
% Returns an annotation table with the folloing variables:
%   id
%   starts
%   ends
%   {x name}_id
%   {y name}_id
%   {x name}_{common vars}
%   {y name}_{common vars}
%   {unique x vars}
%   {unique y vars}
%
% The name in annot.Properties.Description is set to 'intersect_{xname}_{yname}'

if nargin == 2
  y=bml_annot_table(x,[],inputname(2));
  x=bml_annot_table(cfg,[],inputname(1));
  cfg=[];
  description = ['intersect_' x.Properties.Description '_' y.Properties.Description];
elseif nargin == 3
  if ischar(cfg) || iscellstr(cfg) || isstring(cfg)
    cfg = struct('keep',cellstr(cfg));
  end
  x=bml_annot_table(x,[],inputname(2));
  y=bml_annot_table(y,[],inputname(3));
  description = ['intersect_' x.Properties.Description '_' y.Properties.Description];
  description = bml_getopt(cfg,'description',description);
else
  error('incorrect use of bml_annot_intersect')
end

keep      = bml_getopt_single(cfg,'keep','both');
warn      = bml_getopt(cfg,'warn',true);
groupby   = bml_getopt(cfg,'groupby',[]);
groupby_x = bml_getopt(cfg,'groupby_x',groupby);
groupby_y = bml_getopt(cfg,'groupby_y',groupby);


if isempty(x.Properties.Description); x.Properties.Description = 'x'; end
if isempty(y.Properties.Description); y.Properties.Description = 'y'; end

if strcmp(x.Properties.Description,y.Properties.Description)
  x.Properties.Description = [x.Properties.Description '_x'];
  y.Properties.Description = [y.Properties.Description '_y'];
end

xidn=[x.Properties.Description '_id'];
yidn=[y.Properties.Description '_id'];

%ToDo: allow grouping by several variables
if isempty(groupby_x) && isempty(groupby_y)
  x.groupby_=ones(height(x),1);
  y.groupby_=ones(height(y),1);
  groupby_x = {'groupby_'};
  groupby_y = {'groupby_'};
  groups={1};
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
  if isempty(groups)
    annot = [];
    return
  end

else
  error('groupby_x and groupby_y should be both given or none at all')
end

annot = table();
for g=1:numel(groups)
  if iscellstr(groups(g))
    x_g = x(strcmp(x{:,groupby_x},groups(g)),:);
    y_g = y(strcmp(y{:,groupby_y},groups(g)),:);
  else
    x_g = x(x{:,groupby_x}==groups{g},:);   
    y_g = y(y{:,groupby_y}==groups{g},:);   
  end

  %optimizing for special cases
  if isempty(y_g); continue; end
	if height(y_g)==1
    ovlp_y = false;
    x_g = x_g(x_g.ends > y_g.starts(1) & x_g.starts < y_g.ends(1),:);
  else
    ovlp_y = ~isempty(bml_annot_overlap(y_g));
    if ovlp_y
      error('''y'' has overlaps for group %s',string(groups(g)))
    end 
  end
	if isempty(x_g); continue; end
  ovlp_x = ~isempty(bml_annot_overlap(x_g));
  
  i=1; j=1;
  annot_g = cell2table(cell(0,5)); 
  annot_g.Properties.VariableNames = {'starts','ends',xidn,yidn,groupby_x{1}};
  if ovlp_x
    while i<=height(x_g) && j<=height(y_g)
      if x_g.starts(i) < y_g.ends(j) && x_g.ends(i) > y_g.starts(j)
        annot_g = [annot_g;{...
          max(x_g.starts(i),y_g.starts(j)),...
          min(x_g.ends(i),y_g.ends(j)),...
          x_g.id(i),...
          y_g.id(j),...
          groups{g}}];
        if x_g.ends(i) < y_g.ends(j) || j >= height(y_g)
          i = i + 1;
          j=1;
        else
          j = j + 1;
        end
      elseif x_g.ends(i) <= y_g.starts(j) || j >= height(y_g)
        i=i+1;
        j=1;
      elseif x_g.starts(i) >= y_g.ends(j)
        j=j+1;
      else
        error('Unsupported input annotations tables');
      end
    end
  else %no overlaps in x
    while i<=height(x_g) && j<=height(y_g)
      if x_g.starts(i) < y_g.ends(j) && x_g.ends(i) > y_g.starts(j)
        annot_g = [annot_g;{...
          max(x_g.starts(i),y_g.starts(j)),...
          min(x_g.ends(i),y_g.ends(j)),...
          x_g.id(i),...
          y_g.id(j),...
          groups{g}}];
        if x_g.ends(i) < y_g.ends(j)
          i = i + 1;
        else
          j = j + 1;
        end
      elseif x_g.ends(i) <= y_g.starts(j)
        i=i+1;
      elseif x_g.starts(i) >= y_g.ends(j)
        j=j+1;
      else
        error('Unsupported input annotations tables');
      end
    end
  end
  annot = [annot; annot_g];
end
annot = bml_annot_table(annot,description);
if isempty(annot); return; end

x.starts=[]; x.ends=[]; % x.Properties.VariableNames{1}=xidn;
y.starts=[]; y.ends=[]; % y.Properties.VariableNames{1}=yidn;
if ~isempty(groupby_x); x.(groupby_x{1})=[]; end
if ~isempty(groupby_y); y.(groupby_y{1})=[]; end

switch keep
  case {'both','keepboth','keep both','keep_both'}
    keep='both';
    common_vars=intersect(x.Properties.VariableNames,y.Properties.VariableNames);
    common_vars_x=ismember(x.Properties.VariableNames,common_vars);
    common_vars_y=ismember(y.Properties.VariableNames,common_vars);
    unique_vars_x=setdiff(x.Properties.VariableNames,common_vars);
    unique_vars_y=setdiff(y.Properties.VariableNames,common_vars);
  case {'none','keepnone','keep none','keep_none'}
    keep='none';
    common_vars_x=[];
    common_vars_y=[];
    unique_vars_x=[];
    unique_vars_y=[];
  case {'x','keepx','keep x','keep_x'}
    keep='x';
    common_vars_x={'id','duration'};
    common_vars_y=[];
    unique_vars_x=setdiff(x.Properties.VariableNames,common_vars_x);
    unique_vars_y=[];
  case {'y','keepy','keep y','keep_y'}
    keep='y';
    common_vars_x=[];
    common_vars_y={'id','duration'};
    unique_vars_x=[];
    unique_vars_y=setdiff(y.Properties.VariableNames,common_vars_y);
  otherwise
    error("unknown value for keep %s. Allowed values are 'both', 'none', 'x' or 'y'",keep);
end

new_names_common_vars_x = strcat([x.Properties.Description '_'],x.Properties.VariableNames(common_vars_x));
if ~isempty(new_names_common_vars_x)
  new_names_common_vars_x_repeated = ismember(new_names_common_vars_x,unique_vars_x);
  if any(new_names_common_vars_x_repeated)
    rm_vars = new_names_common_vars_x(new_names_common_vars_x_repeated);
    for i=1:length(rm_vars)
      if warn
        warning('Overwriting variable %s of table %s',rm_vars{i},x.Properties.Description);
      end
      %common_vars_x(bml_getidx(rm_vars(i),x.Properties.VariableNames))=[];      
      x.(rm_vars{i})=[];
    end
  end
end

new_names_common_vars_y = strcat([y.Properties.Description '_'],y.Properties.VariableNames(common_vars_y));
if ~isempty(new_names_common_vars_y)
  new_names_common_vars_y_repeated = ismember(new_names_common_vars_y,unique_vars_y);
  if any(new_names_common_vars_y_repeated)
    rm_vars = new_names_common_vars_y(new_names_common_vars_y_repeated);
    for i=1:length(rm_vars)
      if warn
        warning('Overwriting variable %s of table %s',rm_vars{i},y.Properties.Description);
      end
      %common_vars_y(bml_getidx(rm_vars(i),y.Properties.VariableNames))=[];
      y.(rm_vars{i})=[];
    end
  end
end

x.Properties.VariableNames(common_vars_x) = new_names_common_vars_x;
y.Properties.VariableNames(common_vars_y) = new_names_common_vars_y;

if ismember(yidn,x.Properties.VariableNames)
  if warn
    warning('Overwriting variable %s from table %s',yidn,x.Properties.Description);
  end
  x.(yidn)=[];
end
if ismember(xidn,y.Properties.VariableNames)
  if warn
    warning('Overwriting variable %s from table %s',xidn,y.Properties.Description);
  end
  y.(xidn)=[];
end

if ismember(keep,{'x','both'})
  annot=join(annot,x,'Keys',xidn);
end
if ismember(keep,{'y','both'})
  annot=join(annot,y,'Keys',yidn);
end

if any(strcmp('groupby_',annot.Properties.VariableNames))
  annot.groupby_ = [];
end






