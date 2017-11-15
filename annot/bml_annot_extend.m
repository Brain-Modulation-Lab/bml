function extended = bml_annot_extend(annot,ext1,ext2)

% BML_ANNOT_EXTEND extends the annotation times
%
% Use as
%   extended = bml_annot_extend(annot,ext1,ext2)
%   extended = bml_annot_extend(annot,[ext1,ext2])
%   extended = bml_annot_extend(annot,ext1)
%
% Positive ext1 extends the begging of the annotation (starts at an earlier
% time). Negative ext1 contracts the begging, i.e. starts at a later time.
% Likewise, positive ext2 ext ends the end of the annotation (ends at a later time)
% and negative ext2 contracts the end (ends at an earlier time).
%
% If ext2 is not specified, it is set to ext1

if nargin == 2
  if length(ext1)==2
    ext2=ext1(2);
    ext1=ext1(1);
  elseif length(ext1)==1
    ext2=ext1;
  else 
    error('incorrect call. See usage')
  end
elseif nargin ~= 3
  error('incorrect call. See usage')
end

annot = bml_annot_table(annot);
annot.starts = annot.starts - ext1;
annot.ends = annot.ends + ext2;

extended = bml_annot_table(annot);




