function annot = bml_annot_intersect(cfg, x, y)

% BML_ANNOT_INTERSECT returns the intersection of two annotation tables
%
% Use as
%   annot = bml_annot_intersect(cfg, x, y);
%   annot = bml_annot_intersect(x, y);
%
% The first argument cfg is a optional configuration structure, which can contain
% the following optional fields:
% cfg.description - string: description of output annotation
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
  x=bml_annot_table(x,[],inputname(2));
  y=bml_annot_table(y,[],inputname(3));
  description = ['intersect_' x.Properties.Description '_' y.Properties.Description];
  description = ft_getopt(cfg,'description',description);
else
  error('use as bml_annot_intersect(x, y)')
end

xidn=[x.Properties.Description '_id'];
yidn=[y.Properties.Description '_id'];

ovlp_x = ~isempty(bml_annot_overlap(x));
ovlp_y = ~isempty(bml_annot_overlap(y));
if ovlp_y; error('''y'' has overlaps'); end

i=1; j=1;
annot = cell2table(cell(0,4)); 
annot.Properties.VariableNames = {'starts','ends',xidn,yidn};

if ovlp_x
  while i<=height(x) && j<=height(y)
    if x.starts(i) < y.ends(j) && x.ends(i) > y.starts(j)
      annot = [annot;{...
        max(x.starts(i),y.starts(j)),...
        min(x.ends(i),y.ends(j)),...
        x.id(i),...
        y.id(j)}];
      if x.ends(i) < y.ends(j) || j >= height(y)
        i = i + 1;
        j=1;
      else
        j = j + 1;
      end
    elseif x.ends(i) <= y.starts(j) || j >= height(y)
      i=i+1;
      j=1;
    elseif x.starts(i) >= y.ends(j)
      j=j+1;
    else
      error('Unsupported input annotations tables');
    end
  end
else %no overlaps in x
  while i<=height(x) && j<=height(y)
    if x.starts(i) < y.ends(j) && x.ends(i) > y.starts(j)
      annot = [annot;{...
        max(x.starts(i),y.starts(j)),...
        min(x.ends(i),y.ends(j)),...
        x.id(i),...
        y.id(j)}];
      if x.ends(i) < y.ends(j)
        i = i + 1;
      else
        j = j + 1;
      end
    elseif x.ends(i) <= y.starts(j)
      i=i+1;
    elseif x.starts(i) >= y.ends(j)
      j=j+1;
    else
      error('Unsupported input annotations tables');
    end
  end
end

annot = bml_annot_table(annot,description);

x.starts=[]; x.ends=[]; % x.Properties.VariableNames{1}=xidn;
y.starts=[]; y.ends=[]; % y.Properties.VariableNames{1}=yidn;

common_vars=intersect(x.Properties.VariableNames,y.Properties.VariableNames);
common_vars_x=ismember(x.Properties.VariableNames,common_vars);
common_vars_y=ismember(y.Properties.VariableNames,common_vars);

x.Properties.VariableNames(common_vars_x)=...
  strcat([x.Properties.Description '_'],x.Properties.VariableNames(common_vars_x));

y.Properties.VariableNames(common_vars_y)=...
  strcat([y.Properties.Description '_'],y.Properties.VariableNames(common_vars_y));

annot=join(annot,x,'Keys',xidn);
annot=join(annot,y,'Keys',yidn);







