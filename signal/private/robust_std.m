function std = robust_std(data, center)

% ROBUST_STD calculates a robust estimation of the standard deaviation
%
% Use as
%   std = robust_std(data, center)
%   std = robust_std(vector)
%
% data - double: vector on whic to calculate the robust std
% center - double: center of the distribution. Defaults to median(data) 

if nargin==1
  center = median(data);
end
s=quantile(abs(data),0.95);
std=0; p=0.5;
while std < 1e4*eps(s) && p < 1
  std=quantile(abs(data - center),p)/norminv((1+p)/2);
  p = p + 0.05;
end
if std < 1e4*eps(s)
  std=0;
end