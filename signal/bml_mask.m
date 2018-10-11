 function masked = bml_mask(cfg, raw)

% BML_MASK creates a new raw file with the specified values masked
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
% cfg.complete_trial - bool, indicates if complete trial is to be masked if
%   any part of it is masked. Defalts to false. If label_colname is given
%   the msking is done per label. 
% cfg.remask_nan - bool, indicating if usign NaNs to remask. Defaults to
%   false. Mutually exclusive with cfg.annot
%
% raw - FT_DATAYE_RAW object
%
% returns a masked FT_DATAYE_RAW structure 

if istable(cfg)
  cfg = struct('annot',cfg);
end
annot          = bml_getopt(cfg,'annot');
label          = bml_getopt(cfg,'label',raw.label);
label_colname  = bml_getopt(cfg,'label_colname',[]);
value          = bml_getopt(cfg,'value',NaN);
complete_trial = bml_getopt(cfg,'complete_trial',false);
remask_nan     = bml_getopt(cfg,'remask_nan',false);

assert(xor(~isempty(annot),istrue(remask_nan)),'cfg.annot or cfg.remask_nan  required');

roi = bml_raw2annot(raw);
masked = raw;

if remask_nan
  if ~isempty(label_colname); warning('label_colname ignored'); end
  if ~isempty(setdiff(masked.label,label)) 
    error('sorry, label selection for remask_nan not implemented');
  end
  if complete_trial %masking complete row if NaN is detected
    for t=1:numel(masked.trial)
      masked.trial{t}(any(isnan(masked.trial{t}),2),:)=value;
    end
  else %masking only NaNs
    if isnan(value)
      warning('Remasking NaNs with NaNs. Nothing done.');
      return
    end
    for t=1:numel(masked.trial)
      masked.trial{t}(isnan(masked.trial{t}))=value;
    end    
  end
  return
end

if isempty(label_colname)
  %label_colname not specified using label info. 
	annot_idx   = bml_getidx(label,masked.label);
  for t=1:height(roi)
    t_annot = bml_annot_filter(annot,roi(t,:));
    for i=1:height(t_annot)
      if complete_trial
        masked.trial{t}(annot_idx,:)=value;       
      else
        [s,e] = bml_crop_idx_valid(roi(t,:), t_annot.starts(i), t_annot.ends(i));
        masked.trial{t}(annot_idx,s:e)=value;
      end
    end
  end

else %annotations assigned to specific channels
  if sum(strcmp(annot.Properties.VariableNames,label_colname))~=1
    error('label_colname should match a column of annot');
  end

  %iterating over labels of annot_label_colname
  ul = unique(annot{:,label_colname});
  for t=1:height(roi)
    t_annot = bml_annot_filter(annot,roi(t,:));    
    for i_ul=1:numel(ul)
      t_annot_l = t_annot(strcmp(t_annot{:,label_colname},ul{i_ul}),:);
      t_annot_idx = bml_getidx(ul{i_ul},masked.label);
      if t_annot_idx > 0 && t_annot_idx <= numel(masked.label)   
        for i=1:height(t_annot_l)
        	if complete_trial
            masked.trial{t}(t_annot_idx,:)=value;       
          else
            [s,e] = bml_crop_idx_valid(roi(t,:), t_annot_l.starts(i), t_annot_l.ends(i));
            masked.trial{t}(t_annot_idx,s:e)=value;
          end
        end
      end
    end
  end
end

