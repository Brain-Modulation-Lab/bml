function [IFR, SpikeBin] = bml_compute_InstantFR(cfg)
%UNTITLED3 Summary of this function goes here
% Author: Witek Lipski
%   Detailed explanation goes here

spkinds = cfg.spkinds;
Nsamples = cfg.Nsamples;
stdg = cfg.filtSD; % this standard deviation is in samples
fs = cfg.fs; % sampling frequency

%% Generate IFR
%t = (1:round(spkSampRate*S.RecDuration))/spkSampRate; %timeseries
SpikeBin = zeros(Nsamples, 1);
spkinds(spkinds < 1) = 1;
SpikeBin(spkinds) = 1; %binary spike vector
%sets up the gaussian filter for spike density estimation
%standard  deviation of the gaussian smoothing
filtx = -4*stdg:1:4*stdg;
filty = normpdf(filtx,0,stdg);
filty = filty/sum(filty);
%20ms gaussian smoothing
IFR = conv2(SpikeBin(:), filty(:), 'same');
%normalize to the number of spikes in the trial as in Gabbiani et al. 1999
IFR = IFR/(sum(IFR)/fs);
IFR = IFR .* sum(SpikeBin);

end

