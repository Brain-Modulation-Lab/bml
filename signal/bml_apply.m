function raw = bml_apply(fun, data)

% BML_APPLY applies a function to the data of each trial
%
% Use as
%   raw = bml_apply(fun, data)
%
% data - FT_DATAYPE_RAW to which to apply the function fun
% fun - function to be applyed to the data
%
% returns a raw with modified trials. 

for i=1:numel(data.trial)
  data.trial{i} = fun(data.trial{i});
end
raw=data;