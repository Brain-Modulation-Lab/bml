function filtered = bml_annot_filter(cfg, annot, filter_annot)

% BML_ANNOT_FILTER returns the annots that intersect with of filter
%
% Use as
%   filtered = bml_annot_filter(cfg, annot, filter_annot);
%   filtered = bml_annot_filter(annot, filter_annot);
%
% The first argument cfg is a optional configuration structure, which can contain
% the following optional fields:
% cfg.overlap - double: fraction of overla required for filter. Defauls 0
%           (touch)
% cfg.description - string: description of output annotation
%
% annot, filter - annot tables with fields 'starts' and 'ends'.
%        'filter' should have no overlapping annotations 
%
% Returns an annotation table with the folloing variables:

if nargin == 2
  overlap = 0;
  filter_annot=bml_annot_table(annot,'filter_annot');
  annot=bml_annot_table(cfg);
elseif nargin == 3
  overlap = bml_getopt(cfg,'overlap',0);
  annot=bml_annot_table(annot);
  filter_annot=bml_annot_table(filter_annot,'filter_annot');
else
  error('use as bml_annot_filter(annot, filter_annot)');
end
annot.Properties.Description = 'annot';

if isempty(annot)
  return
end

intersect = bml_annot_intersect(annot,filter_annot(:,1:4));
intersect = intersect(:,{'annot_id','duration'});
intersect.Properties.VariableNames = {'id','annot_filter_intersect_duration'};

annot_intersect=join(annot(ismember(annot.id,intersect.id),1:4),intersect);
annot_intersect=annot_intersect(annot_intersect.duration ./ annot_intersect.annot_filter_intersect_duration > overlap,:);

filtered = bml_annot_table(annot(ismember(annot.id,annot_intersect.id),:));
