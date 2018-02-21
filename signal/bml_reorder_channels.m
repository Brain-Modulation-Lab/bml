function reordered = bml_reorder_channels(cfg,data)

% BML_REORDER_CHANNELS changes the order of the channels of a raw
%
% Use as
%   reordered = bml_reorder_channels(cfg,data)
%   reordered = bml_reorder_channels(cfg,data)
%
% data - FT_DATATYPE_RAW
% cfg.order - vector of channel indices in desired order
%             if not provided channels are ordered according to 
%             cfg.label if present, or alphabetically
% cfg.label - cellstr with desired order of channes
% returns a reordered raw object

if ~exist('data','var')
  data=cfg;
  cfg=[];
end
new_order = bml_getopt(cfg,'order');
label     = bml_getopt(cfg,'label');
if isempty(new_order)
  if isempty(label)
    [~, new_order] = sort(data.label);
  else
    assert(all(ismember(label, data.label)),"Invalid label. Unknown channels");
    new_order = bml_map(label,data.label,1:length(data.label));
  end
end

for i=1:numel(data.trial)
  data.trial{i} = data.trial{i}(new_order,:); 
end

data.label = data.label(new_order);
reordered=data;