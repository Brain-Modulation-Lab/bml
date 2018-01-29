function U=bml_comavgref_matrix(n,alpha)

% BML_COMAVGREF_MATRIX creates a common average referencing matrix
%
% Use as 
%   U = bml_comavgref_matrix(n,alpha)
%
% U = In - (alpha/n)*Jn

if ~exist('alpha','var')
  alpha=1;
end

U = eye(n)-(alpha/n)*ones(n);
