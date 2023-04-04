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


% helper function isi
function I = isi(D)
spike_samples = find(D~=0);
if length(spike_samples) < 2
    disp('ISI aborting: Not enough spikes in D.');
else
    I = zeros(length(spike_samples)-1,1);
    for i = 1:length(spike_samples)-1
        I(i) = spike_samples(i+1)-spike_samples(i);
    end
end
end



