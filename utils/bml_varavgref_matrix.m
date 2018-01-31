function U=bml_varavgref_matrix(COV)

% BML_VARAVGREF_MATRIX creates a variable average referencing matrix
%
% Use as 
%   U=bml_varavgref_matrix(COV)
%

assert(size(COV,1)==size(COV,2));
n=size(COV,1);

coef = bml_varavgref_coef(COV);
rho = coef./(1 - coef);
rho = rho / sum(rho);

M_V0 = zeros(n,n);
for i=1:n
  for j=1:n
    M_V0(i,j) = rho(j);
  end
end

U = eye(n)-diag(coef)*M_V0;
%U = diag(1./(1-coef))-diag(coef./(1-coef))*M_V0;


