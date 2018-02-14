function annot = bml_annot_detect(cfg, env)

% BML_ANNOT_DETECT identifies annotations thresholding an envelope signal
%
% Use as
%   annot = bml_annot_detect(cfg, raw)
%
% cfg.threshold - double len 1 or 2: lower/upper threshold for the segmentation
% cfg.max_annots - integer: maximun number of regions of interest in a
%       envelope
%
% returns an annotation table

max_annots        = bml_getopt(cfg, 'max_annots', inf);
threshold         = bml_getopt(cfg, 'threshold');
if ~isempty(threshold)
  assert(length(threshold)<=2,"threshold should be of length 1 or 2");
  lower_threshold = threshold(1);
  upper_threshold = threshold(end);
else
  lower_threshold = [];
  upper_threshold = [];
end
upper_threshold   = bml_getopt(cfg, 'upper_threshold', upper_threshold);
lower_threshold   = bml_getopt(cfg, 'lower_threshold', lower_threshold);
assert(~isempty(upper_threshold) & ~isempty(lower_threshold),"cfg.threshold required");

assert(numel(env.label)==1,"One channel in env expected for detection");

annot = table();
for i=1:numel(env.trial)
  i_env = ft_selectdata(struct('trial',i,'feedback','no'), env);
  env_coord = bml_raw2coord(i_env);
  
  zero_cross_ixs = find(abs(diff(sign(env.trial{i}-lower_threshold)))>=1);
  reset_value=min([min(env.trial{i}),0]);
  search_detect = true;
  loop_count = 0;
  while search_detect
  	loop_count = loop_count + 1;
    [env_max, env_max_ix] = max(env.trial{i});       
    assert(loop_count <= max_annots, "More annots detected than max_annots");
        
    if env_max > upper_threshold
    	%finding start and end of current annot
      if isempty(zero_cross_ixs)
        starts = env.time{i}(1)-0.5/env.fsample;
        ends = env.time{i}(end)+0.5/env.fsample;
      elseif env_max_ix <= zero_cross_ixs(1)
        starts = env.time{i}(1)-0.5/env.fsample;
        ends = env.time{i}(zero_cross_ixs(1))+0.5/env.fsample;
      elseif env_max_ix > zero_cross_ixs(end)
      	starts = env.time{i}(zero_cross_ixs(end))-0.5/env.fsample;
        ends = env.time{i}(end)+0.5/env.fsample;
      else
      	zc_ix = find(diff(sign(zero_cross_ixs-env_max_ix)),1);
        starts = env.time{i}(zero_cross_ixs(zc_ix))-0.5/env.fsample;
        ends = env.time{i}(zero_cross_ixs(zc_ix+1))+0.5/env.fsample;
      end
            
      overlaps = false;
      for j=1:height(annot)
        row = annot(j,:);
        if row.starts < ends && row.ends > starts
          overlaps = true;
        end
      end
      if ~overlaps
        annot = [annot; table(starts,ends,env_max,i)];
      end
      [s,e] = bml_crop_idx_valid(env_coord,starts,ends);
      env.trial{i}(1,s:e)=reset_value;
    else
    	search_detect = false;
    end
  end
end

annot = bml_annot_table(annot);
