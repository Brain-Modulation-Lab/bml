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

if iscell(x); x=cell2table(x); end
if isstruct(x); x=struct2table(x); end

if ~strcmp('starts',x.Properties.VariableNames)
  error('x should have variable ''starts''');
end
if ~strcmp('ends',x.Properties.VariableNames)
  error('x should have variable ''ends''');
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


