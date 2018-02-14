function idx = bml_getidx(element,collection)

% BML_GETIDX gets the first indices of the elements in the domain
%
% index 0 for elements not found
%
% Use as
%   index = bml_get_index(element,collection)
%
% elements - array or cell
% domain - collection of elements from where to extract the index
%
% returns an array of natural indices

  if ischar(element)
    element = {element};
  end

  if iscellstr(element)
    assert(iscellstr(collection),'incompatible elements and collection');  
    idx = cellfun(@(x) zero_if_empty(find(strcmp(collection,x),1)),element,'UniformOutput',true);
  elseif iscell(element)
    assert(iscell(collection),'incompatible elements and collection');
    idx = cellfun(@(x) zero_if_empty(find(collection==x,1)),element,'UniformOutput',true);  
  elseif isnumeric(element)
    assert(isnumeric(collection),'incompatible elements and collection');   
    idx = arrayfun(@(x) zero_if_empty(find(collection==x,1)),element); 
  else 
    error('unknown type for element');
  end

  if size(idx,1) > size(idx,2)
    idx = idx';
  end
end

function y = zero_if_empty(x)
  if isempty(x)
    y = 0;
  else
    y = x;
  end
end