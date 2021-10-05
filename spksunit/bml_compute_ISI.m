function [isits] = bml_compute_ISI(D, fs,ISIFILTER)
%BML_COMPUTE_INSTANTISI Summary of this function goes here
%   Author: Witek Lipski
I = isi(D);

isits = zeros(size(D));
k = find(D);

for i=1:length(I)
    isits(k(i):(k(i)+I(i))) = I(i);
end

isits = isits/fs;
isits = movmean(isits,[ISIFILTER, ISIFILTER]);
end

