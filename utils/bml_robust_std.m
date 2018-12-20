function std = bml_robust_std(data, center)

% BML_ROBUST_STD calculates a row-wise robust estimation of the standard deviation
%
% Use as
%   std = robust_std(data, center)
%   std = robust_std(vector)
%
% data - double: row vector or matrix on which to calculate the robust std
%   if data is a matrix, the centering is done by row. 
% center - double: center of the distribution. Defaults to median(data) 
%   if data is a matrix, center has to be a column vector of the same
%   height as data

if ~exist('center','var')
  center = nanmedian(data,2);
end

std = zeros(size(data,1),1);

for i=1:size(data,1)
  s=quantile(abs(data(i,:)),0.95);
  p=0.5;
  while std(i) < 1e4*eps(s) && p < 1
    std(i)=quantile(abs(data(i,:) - center(i)),p)/norminv((1+p)/2);
    p = p + 0.05;
  end
  if std(i) < 1e4*eps(s)
    std(i)=0;
  end
end