function mapped = bml_map(element,domain,codomain,non_domain)

% BML_MAP maps elements based on given domain and codomain
%
% Use as
%   mapped = bml_map(element,domain,codomain)
%
% element - cellstr, cell or array in column format
% domain - cellstr, cell or array. Possible elements to match with in column format
% codomain - cellstr, cell or array. Corresponding elements in column format
% non_domain - optional value to be returned if element is not in domain
%
% returns the corresponding codomain element for each given domain element

if ischar(element)
  element = {element};
end

if size(element,2) > size(element,1); element=element'; end
if size(domain,2) > size(domain,1); domain=domain'; end
if size(codomain,2) > size(codomain,1); codomain=codomain'; end

assert(size(element,2)==1,'element should be column vector');
assert(size(domain,2)==1,'domain should be column vector');
assert(size(codomain,2)==1,'codomain should be column vector');

if exist('non_domain','var')
    out_of_domain = setdiff(element,domain);
    if ~isempty(out_of_domain)
        if ischar(non_domain)
            non_domain = {non_domain};
        end
        domain = cat(1,domain,out_of_domain);
        codomain = cat(1,codomain,repmat(non_domain,length(out_of_domain),1));
    end
end

if iscellstr(element)
  assert(iscellstr(domain),'incompatible elements and domain');
  mapped = cellfun(@(x) codomain(find(strcmp(domain,x),1)),element,'UniformOutput',true);
elseif iscell(element)
  assert(iscell(domain),'incompatible elements and domain');
  mapped = cellfun(@(x) codomain(find(domain==x,1)),element,'UniformOutput',true);  
elseif isnumeric(element)
  assert(isnumeric(domain),'incompatible elements and domain');   
  mapped = arrayfun(@(x) codomain(find(domain==x,1)),element); 
else 
  error('unknown type for element');
end
