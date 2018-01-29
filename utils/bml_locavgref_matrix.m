function U=bml_locavgref_matrix(n,alpha)

% BML_LOCAVGREF_MATRIX creates a local average referencing matrix
%
% Use as 
%   U = bml_locavgref_matrix(n,alpha)
%

if ~exist('alpha','var')
  alpha=1;
end

U = eye(n);
U(1,2)=-alpha;
U(n,n-1)=-alpha;
for i=2:(n-1)
  U(i,i+1)=-alpha/2;
  U(i,i-1)=-alpha/2;
end

