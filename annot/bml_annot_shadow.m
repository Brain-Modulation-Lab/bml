function shadow = bml_annot_shadow(cfg,annot)

% BML_ANNOT_SHADOW creates annotations that 'shadow' the ones in annot
%
% Use as
%   shadow = bml_annot_shadow(cfg,annot)
%
% cfg.direction - double: if positive the shadow is in future time 
%           (defaults to 1)
% cfg.max_duration - double: maximal allowed duration of shadow
% cfg.gap_duration - double: duraton of gap between annot and shadow
%
% shadow inherits all variable names from annot

direction      = bml_getopt(cfg,'direction',1);
gap_duration    = bml_getopt(cfg,'gap_duration',0);
max_duration    = bml_getopt(cfg,'max_duration');

assert(isempty(bml_annot_overlap(annot)),"annot should not contain overlaps")

shadow = annot;
if direction > 0 %shadow into future
  
  for i=1:(height(annot)-1)
    shadow.starts(i) = annot.ends(i) + gap_duration;
    shadow.ends(i) = annot.starts(i+1);
  end
  shadow.starts(end) = annot.ends(end) + gap_duration;
  shadow.ends(end) = inf;
  if ~isempty(max_duration)
    filtvec = shadow.ends-shadow.starts>max_duration;
    shadow.ends(filtvec) = shadow.starts(filtvec) + max_duration;
  end
  
else %shadow into pass
  
  shadow.starts(1) = -inf;
  shadow.ends(1) = annot.starts(1) - gap_duration;
  for i=2:height(annot)
    shadow.starts(i) = annot.ends(i-1) ;
    shadow.ends(i) = annot.starts(i) - gap_duration;
  end
  if ~isempty(max_duration)
    filtvec = shadow.ends-shadow.starts>max_duration;
    shadow.starts(filtvec) = shadow.ends(filtvec) - max_duration;
  end
  
end

