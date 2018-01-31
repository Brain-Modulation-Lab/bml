function [coef, fitted_COV] = bml_varavgref_coef(COV)

% BML_VARAVGREF_COEF calculates the crosstalk coefficients between electrodes
%
% Use as
%   [coef, fitted_COV] = bml_varavgref_coef(COV)
%
% Calculates crosstal coefficients as defined by electrical crosstalk model
%
% Arguments
% COV - variance-covariance matrix between channels
%
% Returns
% coef - vector of crosstalk coefficients 0 <= coef <= 1
% fitted_COV - fitted variance-covariance matrix


assert(isnumeric(COV));
assert(size(COV,1)==size(COV,2));

n = size(COV,1);

  %calculate model values from crosstalk parameters
  function [V0V0,sigma2_S,VkVj,c] = varavgref_model(p)
    
    %p=zeros(1,n)
    VkVj=diag(diag(COV)); % matrix of predicted variances-covariances
    sigma2_S = zeros(1,n); %initializing singal variance 
    c = exp(p)./(exp(p)+1); % vector of crosstalk coefficients
    sum_c = sum(c);
    
    %calculating V0 variance
    V0V0=0; 
    for l=1:n
      for j=1:n
        V0V0 = V0V0 + exp(p(l)+p(j))*COV(l,j);
      end
    end
    V0V0 = V0V0*(sum(exp(p))^(-2));
    
    %calculating signal variances sigma2_S
    for k=1:n
      sigma2_S(k) = (COV(k,k)-(c(k)^2)*V0V0)/(((1-c(k))^2)+2*(c(k)^2)*(1-c(k))/sum_c);
    end
    
    %completing predicted variance-covariance matrix
    for k=1:(n-1)
      for j=(k+1):n
        VkVj(k,j)= c(k)*c(j)*( (1-c(k))*sigma2_S(k)/sum_c + (1-c(j))*sigma2_S(j)/sum_c + V0V0);
        VkVj(j,k)=VkVj(k,j);
      end
    end    
  end

  %cost function
  function [cost, grad] = costfun(p)
    [~,~,VkVj,c] = varavgref_model(p);
    %calculating cost
    cost=0;
    for k=1:n
      for j=1:n
        cost = cost + (VkVj(k,j)-COV(k,j))^2;
      end
    end
    cost = cost / sum(sum(COV.^2));    
    
    %ridge regression on crosstalk coefficients
    cost = cost + (1e-3)*sum(c.^2);
  end

  % optimization routine
  p = zeros(1,n); 
  [f_V0V0,f_sigma2_S,f_VkVj,f_c] = varavgref_model(p);
  
  %first guess based on solving approximated cuadratic expression
  p1 = zeros(1,n);
  for i=1:n
    a_= -f_sigma2_S(i);
    b_= f_sigma2_S(i); 
    b_= b_ + (sum(f_c .* (1-f_c) .* f_sigma2_S)-f_c(i)*(1-f_c(i))*f_sigma2_S(i))/sum(f_c);
    b_= b_ + f_V0V0*sum(f_c);
    c_= -sum(COV(i,:))+COV(i,i);
   
    d_ = b_^2-4*a_*c_;
    if d_ >= 0
      c_k1=(-b_ + sqrt(d_))/(2*a_);
      c_k2=(-b_ - sqrt(d_))/(2*a_);
      if 0<=c_k1 && c_k1<=1
        c_k=c_k1;
      elseif 0<=c_k2 && c_k2<=1
        c_k=c_k2;    
      else
        c_k=(-b_/(2*a_));  
      end
    else
      c_k=(-b_/(2*a_));      
    end
    
    if c_k <=0 
      p1(i) = -10;
    elseif c_k >= 1
      p1(i) = 10;
    else
      p1(i) = log(abs(c_k/(1-c_k)));
    end
  end
  
  %optimizing from first guess
	p=fminunc(@costfun,p1,optimoptions('fminunc','MaxFunctionEvaluations',1e9,'OptimalityTolerance',1e-9));  
  [~,~,fitted_COV,coef] = varavgref_model(p);
  
  %bounding coefficients
  for i=1:n
    if coef(i) > 0.999
      coef(i) = 0.999;
    end
  end
  
%   figure
%   pcolor(fitted_COV)
%   figure
% 	pcolor(COV)

end