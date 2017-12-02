function transfered = bml_annot_transfer(cfg, annot, transfer)

% BML_ANNOT_TRANSFER copies information of transfer to annot
%
% Use as
%   transfered = bml_annot_transfer(cfg, annot, transfer)
%   transfered = bml_annot_transfer(annot, transfer)  
%
% The first argument cfg is a optional configuration structure, which can contain
% the following optional fields:
% cfg.overlap - double: fraction of overla required for filter. Defauls 0
%           (touch)
% cfg.description - string: description of output annotation
%
% annot, transfer - annot tables with fields 'starts' and 'ends'.
%        'filter' should have no overlapping annotations 

if nargin == 2
  overlap = 0;
  transfer = bml_annot_table(annot,[],inputname(2));
  annot = bml_annot_table(cfg,[],inputname(1));
elseif nargin == 3
  overlap = bml_getopt(cfg,'overlap',0);
  annot = bml_annot_table(annot,[],inputname(2));
  transfer = bml_annot_table(transfer,[],inputname(3));
else
  error('use as bml_annot_transfer(annot, filter_annot)');
end

if isempty(annot)
  return
end

if isempty(annot.Properties.Description)
  annot.Properties.Description = 'annot';
  description = 'annot';
else
  description = annot.Properties.Description;
end

intersect = bml_annot_intersect(annot,transfer);
intersect.intersect_duration = intersect.duration;
intersect=intersect(:,setdiff(intersect.Properties.VariableNames,annot.Properties.VariableNames));
intersect.id = intersect.([description '_id']);
intersect.([description '_id']) = [];

annot_intersect=innerjoin(annot,intersect,'Keys','id');

transfered = bml_annot_table(annot_intersect,description);
