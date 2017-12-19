function annot = bml_annot_rowbind(varargin)

% BML_ANNOT_ROWBIND binds tables by rows, conforming to first table
%
% Use as
%    annot = bml_annot_rowbind(annot1, annot2, annot3, ...)

annot = varargin{1};
for i=2:numel(varargin)
  annot = [annot; bml_annot_conform_to(annot, varargin{i})];
end

annot.id=[];
annot = bml_annot_table(annot);