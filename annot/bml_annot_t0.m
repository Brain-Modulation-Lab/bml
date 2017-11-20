function shifted = bml_annot_t0(cfg,annot)

% BML_ANNOT_T0 changes the time reference of an annot table
%
% Use as 
%   shifted = bml_annot_t0(cfg,annot)
%   shifted = bml_annot_t0(t0,annot)
%
% cfg.t0
% cfg.starts
% cfg.roi

if isa(cfg,'double')
  cfg = struct('t0',cfg);
elseif istable(cfg)
  cfg = struct('roi',cfg);
end

t0      = bml_getopt(cfg,'t0');
starts  = bml_getopt(cfg,'starts');
roi     = bml_getopt(cfg,'roi');

if ~isempty(starts)
  t0 = starts;
elseif ~isempty(roi)
  t0 = min(roi.starts);
end

annot.starts = annot.starts - t0;
annot.ends = annot.ends - t0;
if all(ismember({'t1','t2'},annot.Properties.VariableNames))
	annot.t1 = annot.t1 - t0;
  annot.t2 = annot.t2 - t0;
end

shifted = annot;




