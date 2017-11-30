function ordvec = bml_strnumcell2ordvec(strnumcell)

% BML_STRNUMCELL2ORDVEC transform a cell with chars into an ordered double vector
%
% Use as
%   ordvec = bml_strnumcell2ordvec(strnumcell)
%
% strnumcell is a cell array with numbers in character format
%
% ordvec is always a row vector

  ordvec = cellfun(@str2double,strnumcell);
  if size(ordvec,1) > size(ordvec,2)
    ordvec = ordvec';
  end
  ordvec = sort(ordvec);