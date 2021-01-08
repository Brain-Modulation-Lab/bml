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
% cfg.crossfade - int, number of samples to crossfade. Defaults to zero. 
% cfg.complete_trial - bool, indicates if complete trial is to be masked if
%   any part of it is masked. Defalts to false. If label_colname is given
%   the msking is done per label. 
% cfg.remask_nan - bool, indicating if remasking existing NaNs. Defaults to
%   false. Mutually exclusive with cfg.annot and remask_inf
% cfg.remask_inf - bool, indicating if remasking existing Infs. Defaults to
%   false. Mutually exclusive with cfg.annot and remask_nan
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
remask_inf     = bml_getopt(cfg,'remask_inf',false);
crossfade      = bml_getopt(cfg,'crossfade',0);

masked = raw;
roi = bml_raw2annot(raw);

%assert(xor(~isempty(annot),istrue(remask_nan)),'cfg.annot or cfg.remask_nan  required');
if isempty(annot) && ~istrue(remask_nan) && ~istrue(remask_inf)
  %nothing to mask
  return 
end

if crossfade > 0 && complete_trial
  error('complete_trial and crossfade are mutually exclusive options');
end

if remask_inf
  if ~isempty(label_colname); warning('label_colname ignored'); end
  if ~isempty(setdiff(masked.label,label)) 
    error('sorry, label selection for remask_inf not implemented');
  end
	if crossfade > 0
    error('sorry, crossfade for remask_inf not implemented');
  end
  if complete_trial %masking complete row if NaN is detected
    for t=1:numel(masked.trial)
      masked.trial{t}(any(isinf(masked.trial{t}),2),:)=value;
    end
  else %masking only Infs
    for t=1:numel(masked.trial)
      masked.trial{t}(isinf(masked.trial{t}))=value;
    end    
  end
  return
end

if remask_nan
  if ~isempty(label_colname); warning('label_colname ignored'); end
  if ~isempty(setdiff(masked.label,label)) 
    error('sorry, label selection for remask_nan not implemented');
  end
	if crossfade > 0
    error('sorry, crossfade for remask_nan not implemented');
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
        if crossfade > 0
          if s>1 %fading in 
            fi_s = max(s-crossfade+1,1);
            fi_n = (s-fi_s); %effective fade in number of samples
            %fi_ramp = ((crossfade-fi_n):(crossfade-1))./crossfade;
            %fi_ramp = ((-(fi_n)/2):((crossfade/2)-1)) .* 6 ./ (crossfade./2);
            fi_ramp = 6.*2.*((((crossfade-fi_n):(crossfade-1))./crossfade)-0.5);   
            fi_ramp = 1./(1+exp(-fi_ramp));
            masked.trial{t}(annot_idx,fi_s:(s-1))=fi_ramp .* value + (1-fi_ramp) .* masked.trial{t}(annot_idx,fi_s:(s-1));
            end

          ns = size(masked.trial{t},2); %number of samples of trial
          if e < ns%fading out
            fo_e = min(e+crossfade-1,ns);
            fo_n = (fo_e-e); %effective fade in number of samples
            %fo_ramp = (1:fo_n)./crossfade;
            %fo_ramp = ((-(fo_n)/2):((crossfade/2)-1)) .* 6 ./ (crossfade./2);
            fo_ramp = 6.*2.*(((1:fo_n)./crossfade)-0.5);
            fo_ramp = 1./(1+exp(-fo_ramp));
            masked.trial{t}(annot_idx,(e+1):fo_e)=(1-fo_ramp) .* value + fo_ramp .* masked.trial{t}(annot_idx,(e+1):fo_e);
          end
        end
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
            if crossfade > 0
              if s>1 %fading in 
                fi_s = max(s-crossfade+1,1);
                fi_n = (s-fi_s); %effective fade in number of samples
                %fi_ramp = ((crossfade-fi_n):(crossfade-1))./crossfade;
                %fi_ramp = ((-(fi_n)/2):((crossfade/2)-1)) .* 6 ./ (crossfade./2);
                fi_ramp = 6.*2.*((((crossfade-fi_n):(crossfade-1))./crossfade)-0.5);   
                fi_ramp = 1./(1+exp(-fi_ramp));
                masked.trial{t}(t_annot_idx,fi_s:(s-1))=fi_ramp .* value + (1-fi_ramp) .* masked.trial{t}(t_annot_idx,fi_s:(s-1));
               end
              
              ns = size(masked.trial{t},2); %number of samples of trial
              if e < ns%fading out
                fo_e = min(e+crossfade-1,ns);
                fo_n = (fo_e-e); %effective fade in number of samples
                %fo_ramp = (1:fo_n)./crossfade;
                %fo_ramp = ((-(fo_n)/2):((crossfade/2)-1)) .* 6 ./ (crossfade./2);
                fo_ramp = 6.*2.*(((1:fo_n)./crossfade)-0.5);
                fo_ramp = 1./(1+exp(-fo_ramp));
                masked.trial{t}(t_annot_idx,(e+1):fo_e)=(1-fo_ramp) .* value + fo_ramp .* masked.trial{t}(t_annot_idx,(e+1):fo_e);
              end
              
            end
          end
        end
      end
    end
  end
end

