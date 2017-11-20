function bml_annot_plot(annot, varargin)

% BML_ANNOT_PLOT plots an annotation table
%
% Use as
%   bml_annot_plot(annot, varargin)
%
% annot - annotation table
% varargin - further arguments for plot

annot = bml_annot_table(annot);
if isempty(varargin)
  varargin={'LineWidth',0.5};
end

for i=1:height(annot)
  hold on;
  plot([annot.starts(i),annot.ends(i)],[annot.id(i),annot.id(i)],varargin{:})
end