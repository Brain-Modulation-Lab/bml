function bml_annot_plot(cfg, annot, varargin)

% BML_ANNOT_PLOT plots an annotation table
%
%
%

annot = bml_annot_table(annot);
if isempty(varargin)
  varargin={'LineWidth',0.5};
end

for i=1:height(annot)
  hold on;
  plot([annot.starts(i),annot.ends(i)],[annot.id(i),annot.id(i)],varargin{:})
end