function [freq] = bml_freqanalysis_power_wavelet(cfg, data)

% BML_FREQANALYSIS_POWER_WAVELET performs 'morlet' wavelet time-frequency 
% power analysis using mulitplication in the frequency domain. This function 
% is a wrapper over ft_freqanalysis. 
%
% Use as
%   [freq] = bml_freqanalysis_wavelet(cfg, data)
%
%   cfg.foi         = vector 1 x numfoi, frequencies of interest
%                   defaults to round(10.^(0.00:0.05:2.4),2,'signif')
%
%   cfg.toilim      = [begin end], time range of interest. Defaults to
%                     largest range possible across trials. Wider epochs
%                     than toilim can be used to define edge buffer zones.  
%   cfg.dt          = time step of time-frequency representation (width of pixel)
%                     This parameter should be selected based on the
%                     uncertatunty in events used for time-locking.
%                     Defaults to 20ms. 
%   cfg.width       = 'width', or number of cycles, of the wavelet (default = 7)
%   cfg.gwidth      = determines the length of the used wavelets in standard
%                     deviations of the implicit Gaussian kernel and should
%                     be choosen >= 3; (default = 3)
%
% Sigma in the frequency domain (sf) at frequency f0 is defined as: sf = f0/width
% Sigma in the temporal domain (st) at frequency f0 is defined as: st = 1/(2*pi*sf)
% 
% width   fmultfactor   overlap
%     7      10^(1/3)      1.3%
%     7      10^(1/4)      5.8%
%     7      10^(1/5)     12.7%
%     7      10^(1/6)     20.3%

cfg.width        = bml_getopt(cfg,'width',7);
cfg.gwidth       = bml_getopt(cfg,'gwidth',3);
cfg.foi          = bml_getopt(cfg,'foi',round(10.^(0.30:0.05:2.4),2,'signif'));

% dealing with requested times of interest
dt        = bml_getopt(cfg,'dt',0.020); %width of pixels in returned matrix
epoch     = bml_raw2annot(data);
toirange  = [max(epoch.starts), min(epoch.ends)];
toirange  = round(toirange,9);
toilim    = bml_getopt(cfg,'toilim',toirange);
toilim    = round(toilim,9);
% cfg.toi = (ceil(toilim(1)./dt):1:floor(toilim(2)./dt)).*dt;

%dealing with times of interest required not to loose data at high
%frequencies. The time resolution neccesary for the tf analysis depends on
%the highest frequency used.
dtsubsampfactor  = ceil((2.*max(cfg.foi)./cfg.width).*dt); %dt sampling factor for high frequencies
dthf             = dt ./ dtsubsampfactor; %dt required for high frequencie
cfg.toi = ( (ceil(toirange(1)./dt)*dtsubsampfactor):1:(floor(toirange(2)./dt)*dtsubsampfactor-1) ) .* dthf;

% calling fieldtrip function 
cfg.output       = 'pow';
cfg.method       = 'wavelet';
cfg.feedback     = 'no';
cfg.keeptrials   = 'yes';
cfg.keeptapers   = 'no';
cfg.pad          = 'nextpow2';

freq = ft_freqanalysis(cfg, data);

% checking dimension order
if ~strcmp(freq.dimord,'rpt_chan_freq_time')
  error('incorrect dimord')
end

% averaging samples in groups of dtsubsampfactor. Sub sampling to dt. 
s2 = size(freq.time,2);
m = s2 - mod(s2,dtsubsampfactor);
tmp = reshape(round(freq.time(1:m),9,'signif'),dtsubsampfactor,[]);
freq.time = mean(tmp,1);

s = size(freq.powspctrm);
tmp = reshape(freq.powspctrm(:,:,:,1:m),s(1),s(2),s(3),dtsubsampfactor,m./dtsubsampfactor);
freq.powspctrm = squeeze(mean(tmp,4));

% selecting toilim
cfg1=[];
cfg1.latency = toilim;
freq = ft_selectdata(cfg1,freq);


