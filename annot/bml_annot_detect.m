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

annot = table();
for i=1:numel(env.trial)
  
  cfg1=[];
  cfg1.trials=i;
  cfg1.feedback='no';
  env_coord = bml_raw2coord(ft_selectdata(cfg1,env));

	fprintf("\nDetecting trial %i, labels: \n",i);
     
  for l=1:numel(env.label)
    label = env.label(l);
    fprintf("%s ",label{1});
    if mod(l,10)==0
      fprintf("\n",label{1});
    end
    
    zero_cross_ixs = find(abs(diff(sign(env.trial{i}(l,:)-lower_threshold),1,2))>=1);

    %dealing with negative values for reset
    reset_value=min(env.trial{i}(l,:),[],2);
    reset_value(reset_value>0)=0;

    search_detect = true;
    loop_count = 0;
    annot_l = table();
    while search_detect
      loop_count = loop_count + 1;
      [env_max, env_max_ix] = max(env.trial{i}(l,:),[],2);       
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
        for j=1:height(annot_l)
          row = annot_l(j,:);
          if row.starts < ends && row.ends > starts
            overlaps = true;
          end
        end
        if ~overlaps
          trial = i;
          annot_l = [annot_l; table(starts,ends,env_max,trial,label)];
        end
        [s,e] = bml_crop_idx_valid(env_coord,starts,ends);
        env.trial{i}(l,s:e)=reset_value;
      else
        search_detect = false;
      end
    end
    annot = [annot; annot_l];
  end
end

annot = bml_annot_table(annot);
