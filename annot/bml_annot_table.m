function annot=bml_annot_table(x, description, x_var_name)

% BML_ANNOT_TABLE transforms a table into an annotations table [internal]
%
% Use as
%   annot=bml_annot_table(x)
%   annot=bml_annot_table(x, description)
%   annot=bml_annot_table(x, [], x_var_name)
%
% x - table: should contains 'starts' and 'ends' variables
% description - string: description of the annotation table
% x_var_name - string: name of the variable used for the annot table, as
%     returned by inputname(). Usefull for anidated calls.
%
% returns a table with variables 'id', 'starts', 'ends' and any additonal
% variable present in x. Issues a error on inconsistent input. 

if isempty(x) 
  x=table();
end

if isnumeric(x)
  if size(x,1) < size(x,2)
    x = x';
  end
  x = table(x);
end
if iscell(x); x=cell2table(x); end
if isstruct(x); x=struct2table(x); end

if ~exist('description','var') || isempty(description)
  if isempty(x.Properties.Description)
    if exist('x_var_name','var')
      description=x_var_name;
    else
      description=inputname(1);
    end
  else
    description=x.Properties.Description;
  end
end

if iscellstr(description) 
  if numel(description)==1
    description = description{1};
  else
    error('The Description property must be a character vector.');
  end
end

if isempty(x)
  annot=table();
  annot.Properties.Description = description;
  return
end

if ~strcmp('starts',x.Properties.VariableNames)
  if width(x)<=2 
    x.Properties.VariableNames(1)={'starts'};
  else
    error('x should have variable ''starts''');
  end
end
if ~strcmp('ends',x.Properties.VariableNames)
  if width(x)==1 
    x.ends = x.starts;
  elseif width(x)==2 
    x.Properties.VariableNames(2)={'ends'};
  else
    error('x should have variable ''ends''');
  end
end

x=sortrows(x,'starts');

if ~strcmp('id',x.Properties.VariableNames)
  x = [table(transpose(1:height(x)),'VariableNames',{'id'}), x];
elseif length(unique(x.id)) < height(x)
  error('inconsistent id variable')
end

if any(strcmp('duration',x.Properties.VariableNames))
  x.duration = [];
end
x = [x, table(x.ends - x.starts,'VariableNames',{'duration'})];

annot = bml_annot_reorder_vars(x, {'id','starts','ends','duration'});
annot.Properties.Description = description;


