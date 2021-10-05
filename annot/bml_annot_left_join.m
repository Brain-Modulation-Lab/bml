function joined = bml_annot_left_join(cfg, left, right)

% BML_ANNOT_LEFT_JOIN performs a left join operation on annnotation tables
%
% Use as
%   joined = bml_annot_left_join(cfg, left, right)
%   joined = bml_annot_left_join(left, right)
%
% The first argument cfg is a optional configuration structure, which can contain
% the following optional fields:
% cfg.keys - cellstr: Variables to use as keys 
% cfg.description - string: description of output annotation
% cfg.select - cellstr. Names of variables to transfer. Defaults to
%   variables in right not present in left
%
% joined - annotation tables with rows of left plus additional columns from right

if nargin == 2
  right = left;
  left = bml_annot_table(cfg,[],inputname(1));
  cfg=[];
elseif nargin == 3
	left = bml_annot_table(left,[],inputname(2));
else
  error('use as bml_annot_left_join(left, right)');
end

if isempty(left)
  joined=left;
  return
end

description = bml_getopt(cfg,'description',[]);
if isempty(description)
  if isempty(left.Properties.Description)
    left.Properties.Description = 'left';
    description = 'joined';
  else
    description = left.Properties.Description;
  end
end

keys = intersect(...
        left.Properties.VariableNames(endsWith(left.Properties.VariableNames,'_id')),...
        right.Properties.VariableNames(endsWith(right.Properties.VariableNames,'_id')));
keys = bml_getopt(cfg,'keys',keys);
if isempty(keys)
  error('select valid keys to join');
end

select = setdiff(right.Properties.VariableNames,left.Properties.VariableNames);
select = bml_getopt(cfg,'select',select);
if ~isempty(select)
  select_members = ismember(select,right.Properties.VariableNames);
  if ~all(select_members)
    warning('%s variables not found. Available vars are %s',...
      strjoin(select(~select_members)),strjoin(right.Properties.VariableNames));
  end
  right = right(:,[keys{:},select(select_members)]); % MV: fixed for cell array... before it was right = right(:,[keys,select(select_members)])
end

joined=outerjoin(left,right,'Keys',cellstr(keys),'Type','left','MergeKeys',true); % MV: fixed for cell array... before it was joined=outerjoin(left,right,'Keys',keys,'Type','left','MergeKeys',true);

joined = bml_annot_table(joined,description);
