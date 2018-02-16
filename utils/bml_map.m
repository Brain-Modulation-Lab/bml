function mapped = bml_map(element,domain,codomain)

% BML_MAP maps elements based on given domain and codomain
%
% Use as
%   mapped = bml_map(element,domain,codomain)
%
% element - cellstr, cell or array
% domain - cellstr, cell or array. Possible elements to match with
% codomain - cellstr, cell or array. Corresponding elements
%
% returns the corresponding codomain element for each given domain element

if ischar(element)
  element = {element};
end

if iscellstr(element)
  assert(iscellstr(domain),'incompatible elements and domain');  
  assert(iscellstr(codomain),'incompatible elements and codomain');  
  mapped = cellfun(@(x) codomain(find(strcmp(domain,x),1)),element,'UniformOutput',true);
elseif iscell(element)
  assert(iscell(domain),'incompatible elements and domain');
  assert(iscell(codomain),'incompatible elements and codomain');  
  mapped = cellfun(@(x) codomain(find(domain==x,1)),element,'UniformOutput',true);  
elseif isnumeric(element)
  assert(isnumeric(domain),'incompatible elements and domain');   
  assert(isnumeric(codomain),'incompatible elements and codomain');
  mapped = arrayfun(@(x) codomain(find(domain==x,1)),element); 
else 
  error('unknown type for element');
end
