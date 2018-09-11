function transfered = bml_annot_transfer(cfg, annot, transfer)

% BML_ANNOT_TRANSFER copies information of transfer to annot
%
% Use as
%   transfered = bml_annot_transfer(cfg, annot, transfer)
%   transfered = bml_annot_transfer(cfg.select, annot, transfer)
%   transfered = bml_annot_transfer(annot, transfer)  
%
% The first argument cfg is a optional configuration structure, which can contain
% the following optional fields:
% cfg.overlap - double: fraction of overla required for filter. Defauls 0
%           (touch)
% cfg.description - string: description of output annotation
% cfg.select - cellstr. Names of variables to transfer (after name
%           modification)
%
% annot, transfer - annot tables with fields 'starts' and 'ends'.
%        'transfer' should have no overlapping annotations 

if nargin == 2
  overlap = 0;
  transfer = bml_annot_table(annot,[],inputname(2));
  annot = bml_annot_table(cfg,[],inputname(1));
  cfg=[];
elseif nargin == 3
    if isstruct(cfg)
      overlap = bml_getopt(cfg,'overlap',0);
    else %case cfg.select is first argument
      overlap = 0;
      cfg=struct('select',cfg);
    end
	annot = bml_annot_table(annot,[],inputname(2));
	transfer = bml_annot_table(transfer,[],inputname(3));
else
  error('use as bml_annot_transfer(annot, filter_annot)');
end

if isempty(annot)
  return
end

description = bml_getopt(cfg,'description',[]);
if isempty(description)
  if isempty(annot.Properties.Description)
    annot.Properties.Description = 'annot';
    description = 'annot';
  else
    description = annot.Properties.Description;
  end
end

intersect = bml_annot_intersect(annot,transfer);
intersect.intersect_duration = intersect.duration;
intersect=intersect(:,setdiff(intersect.Properties.VariableNames,annot.Properties.VariableNames));
intersect.id = intersect.([description '_id']);
intersect.([description '_id']) = [];

if length(unique(intersect.id)) < length(intersect.id)
  error("can't transfer variables. Inconsistent mapping");
end

select = bml_getopt(cfg,'select',[]);
if ~isempty(select)
  select_members = ismember(select,intersect.Properties.VariableNames);
  if ~all(select_members)
    warning('%s variables not found. Available vars are %s',...
      strjoin(select(~select_members)),strjoin(intersect.Properties.VariableNames));
  end
  intersect = intersect(:,[{'id'},select(select_members)]);
end

annot_intersect=innerjoin(annot,intersect,'Keys','id');

transfered = bml_annot_table(annot_intersect,description);
