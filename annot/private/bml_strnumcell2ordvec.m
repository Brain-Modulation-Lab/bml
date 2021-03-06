function ordvec = bml_strnumcell2ordvec(strnumcell)

% BML_STRNUMCELL2ORDVEC transform a cell with chars into an ordered double vector
%
% Use as
%   ordvec = bml_strnumcell2ordvec(strnumcell)
%
% strnumcell is a cell array with numbers in character format
%
% ordvec is always a row vector

if iscell(strnumcell)
  ordvec = cellfun(@str2double,strnumcell);
elseif isnumeric(strnumcell)
  ordvec = strnumcell;
else
  ordvec = str2double(strnumcell);  
end
if size(ordvec,1) > size(ordvec,2)
  ordvec = ordvec';
end
ordvec = sort(ordvec);  
  