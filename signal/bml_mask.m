 function masked = bml_mask(cfg, raw)

% BML_MASK created a new raw file with specified values masked
% 
% Use as
%   raw = bml_mask(cfg, raw)
%   raw = bml_annot2raw(cfg.annot, mask)
%
% cfg.annot - annotation table specifying which values to mask
% cfg.label - str or cellstr indicating label(s) to mask. Default to 
%   raw.label
% cfg.label_colname - str indicating annot column with label
%   specification. Defaults to empty, in which case 
%   cfg.label is used for all annotations. If present, overwrites cfg.label. 
% cfg.value - value used to mask. Defaults to NaN.
%
% raw - FT_DATAYE_RAW object
%
% returns a masked FT_DATAYE_RAW structure 

if istable(cfg)
  cfg = struct('annot',cfg);
end
annot         = bml_getopt(cfg,'annot');
label         = bml_getopt(cfg,'label',raw.label);
label_colname = bml_getopt(cfg,'label_colname',[]);
value         = bml_getopt(cfg,'value',NaN);

assert(~isempty(annot),'cfg.annot required');

masked = raw;
roi = bml_raw2annot(masked);

if isempty(label_colname)

  %label_colname not specified using label info. 
	annot_idx   = bml_getidx(label,masked.label);
  for t=1:height(roi)
    t_annot = bml_annot_filter(annot,roi(t,:));
    for i=1:height(t_annot)
      [s,e] = bml_crop_idx_valid(roi(t,:), t_annot.starts(i), t_annot.ends(i));
      masked.trial{t}(annot_idx,s:e)=value;
    end
  end

else %annotations assigned to specific channels
  if sum(strcmp(annot.Properties.VariableNames,label_colname))~=1
    error('label_colname should match a column of annot');
  end

  %iterating over labels of annot_label_colname
  ul = unique(annot{:,label_colname});
  for i_ul=1:numel(ul)
    annot_l = annot(strcmp(annot{:,label_colname},ul{i_ul}),:);
    annot_idx = bml_getidx(ul{i_ul},masked.label);
    if annot_idx > 0 && annot_idx <= numel(masked.label)
      for t=1:height(roi)
        t_annot_l = bml_annot_filter(annot_l,roi(t,:));
        for i=1:height(t_annot_l)
          [s,e] = bml_crop_idx_valid(roi(t,:), t_annot_l.starts(i), t_annot_l.ends(i));
          masked.trial{t}(annot_idx,s:e)=value;
        end
      end
    end
  end
end

