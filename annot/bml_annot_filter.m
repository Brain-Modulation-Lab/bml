function filtered = bml_annot_filter(cfg, annot, filter_annot)

% BML_ANNOT_FILTER returns the annots that intersect with the filter
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

if isempty(annot) %optimization for empty filess
  filtered = annot;
  return
end

if overlap==0 && height(filter_annot)==1 %optimization for single row touch
  filtered = annot(annot.starts < filter_annot.ends(1) & annot.ends > filter_annot.starts(1),:);
  return
end

intersect = bml_annot_intersect(annot,filter_annot(:,1:4));
if isempty(intersect)
  filtered = table();
  return
end
intersect = intersect(:,{'id','starts','ends','duration','annot_id'});
if overlap>0
  cfg=[];
  cfg.criterion = @(x) (length(unique(x.annot_id))==1);
  intersect = bml_annot_consolidate(cfg,intersect);
  intersect = intersect(:,{'annot_id','cons_duration'});
  intersect.Properties.VariableNames = {'id','annot_filter_intersect_duration'};

  annot_intersect=join(annot(ismember(annot.id,intersect.id),1:4),intersect);
  duration_ratio = annot_intersect.annot_filter_intersect_duration ./ annot_intersect.duration;
  annot_intersect=annot_intersect((duration_ratio >= overlap) | (isnan(duration_ratio)),:);

  filtered = bml_annot_table(annot(ismember(annot.id,annot_intersect.id),:));
else
  filtered = annot(ismember(annot.id,intersect.annot_id),:);
end
