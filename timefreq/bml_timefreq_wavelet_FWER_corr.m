function [alpha, n_comp] = bml_timefreq_wavelet_FWER_corr(cfg)
% BML_TIMEFRQ_WAVELET_FWER_CORR estimates number of independent comparisons in a time frequency analysis
%
% Parameters
%   cfg.foi - vector with frequencies of interest
%   cfg.toi - vector with times of interest
%   cfg.width - width of wavlet (fixed for all freqs). Defaults to 7.
%   cfg.fwer - family wise error rate. Defaults to 0.05
%
% Returns
%   alpha - significance threshold for uncorrected pvalues
%   n_comp - Estimated number of independent components

method = bml_getopt(cfg,'method','wavelet');
if ~strcmp(method, 'wavelet')
  error('only method = wavelet supported');
end

foi = bml_getopt(cfg,'foi',[]);
toi = bml_getopt(cfg,'toi',[]);
w   = bml_getopt(cfg,'width',7);
fwer = bml_getopt(cfg,'fwer',0.05);

dt=0.01;
df=0.1;
tbuff = 3 ./ min(foi);
tv = min(toi)-tbuff + dt .* (0:ceil((range(toi) + 1.2.* tbuff) ./ dt));
fv = df .* (1:ceil(max(foi).*2/df));


%heuristic brute force approach
count_v=[];
tfm = zeros(length(fv),length(tv));
for t0i=1:3
  t0 = toi(t0i);
  fprintf('time %i ',t0i);
  count = 0;
  for f0i=1:length(foi)
    f0 = foi(f0i);
    psf_t = exp( (-2 .* f0.^2 .* pi.^2 .* (tv - t0).^2) ./ w.^2);
    psf_f = exp( -((fv - f0).^2 .* w.^2)/(2 .* f0.^2));
    psf1 =  psf_f' * psf_t;
    psf2 = psf1 - tfm;
    psf2(psf2<0)=0;
    count = count + sum(sum(psf2,2),1)*dt*df;
    tfm = tfm + psf2;
  end
  count_v = [count_v, count];
  fprintf('count = %f \n', count);
end
fprintf('assuming additional %i times increment the count by the same amount',length(toi)-1);
n_comp = ceil(count_v(1) + count_v(2) .* (length(toi)-1));
alpha = fwer/n_comp;
