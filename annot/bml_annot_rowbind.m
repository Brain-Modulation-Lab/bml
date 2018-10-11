function annot = bml_annot_rowbind(varargin)

% BML_ANNOT_ROWBIND binds tables by rows, conforming to first non-empty table
%
% Use as
%    annot = bml_annot_rowbind(annot1, annot2, annot3, ...)

annot = table();
for i=1:numel(varargin)
  if ~isempty(varargin{i})
    if isempty(annot)
      annot = varargin{i};
    else
      annot = [annot; bml_annot_conform_to(annot, varargin{i})];
    end
  end
end

annot.id=[];
annot = bml_annot_table(annot);