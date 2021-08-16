function IS = bml_isolation_score(X, Y,lambda)
% Author: Matteo Vissani

% this script computes the isolation score according the algorithm
% proposide by Jousha et al 2007. This script is far from beeing optimized
% and it can require a lot of time if there are many events. If you have in
% mind any optimization, please do it! There are too many for loops so
% maybe a vectorized implementation could improve a lot the performance!

% n_events = number of spikes; n_dims = number of principal components
% (usually 2 or 3)

% Inputs:
%       - X: Principale components of the cluster (n_events x n_dims)
%       - Y: Principal components of all the rest (noise + other clusters)
%       (n_events x n_dims)
%       - lambda: parameter that weights the euclidean distance in the
%       algorithm and sets the trade-off between false positive and false
%       negative errors (10 is a good starting value according Jousha et al
%       2007)
% Output:
%       - IS: isolation score in the n_dims principal component space
%       (scalar value between 0 --> no isolation  and 1 --> perfectly isolated) 

nX = size(X,1);
nY = size(Y,1);
distX = zeros(nX,nX-1);
sim = zeros(nX, nX + nY-1);
for ii = 1 : nX
    cont = 1;
    for jj = 1 : nX
        if ii ~= jj
            distX(ii,cont) = norm(X(ii,:) - X(jj,:));
            cont = cont+1;
        end
    end
end
d0 = mean(distX(:));

for ii = 1 : nX
    cont = 1;
    for jj = 1 : nX
        if ii ~= jj
            sim(ii,cont) = exp(-norm(X(ii,:) - X(jj,:))*lambda/d0);
            cont = cont+1;
        end
    end
end

for ii = 1 : nX
    for jj = 1 : nY 
        sim(ii,jj+nX-1) = exp(-norm(X(ii,:) - Y(jj,:))*lambda/d0);
    end   
end
sim_norm = zeros(nX, nX + nY-1);
for ii = 1 : nX
    sim_norm(ii,:) = sim(ii,:)/sum(sim(ii,:));
end
Px = sum(sim_norm(:,1:nX-1),2);
IS = mean(Px);
end


