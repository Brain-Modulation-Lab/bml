function renamed = bml_annot_rename(annot,varargin)

% BML_ANNOT_RENAME changes the names of columns
%
% Use as
%    renamed = bml_annot_rename(annot, 'old_col1', 'new_col1', 'old_col2', 'new_col2',...)

annot = bml_annot_table(annot);

if mod(numel(varargin),2) ~= 0
  error('matching old and new column names required');
end

for i=1:(numel(varargin)/2)
  old_var = varargin((i-1)*2+1);
  new_var = varargin(i*2);
  if ~ismember(old_var,annot.Properties.VariableNames)
    error('variable %s not present in annotation table', old_var)
  else
    idx = find(ismember(annot.Properties.VariableNames,old_var),1);
    annot.Properties.VariableNames(idx) = new_var;
  end
end

renamed = annot;