function [D_hg] = bml_extractgamma(cfg, D)


%% loading electrode type band table
% if ~exist('el_band','var')
%   param = readtable([PATH_ART_PROTOCOL, filesep, 'artifact_', ARTIFACT_CRIT , '_params.tsv'],'FileType','text');
%   param_default = param(param.subject == "default",:);
%   param_subject = param(strcmp(param.subject,SUBJECT),:);
%   if ~isempty(param_subject)
%     param = bml_annot_rowbind(param_default(~ismember(param_default.name,param_subject.name),:),param_subject);
%   end
% end

nfreqs        = bml_getopt(cfg,'nfreqs', 10);
wav_freq_min  = bml_getopt(cfg,'wav_freq_min',70);
wav_freq_max  = bml_getopt(cfg,'wav_freq_max',150);
wav_width  = bml_getopt(cfg,'wav_width', 7);
fs_out        = bml_getopt(cfg,'fs_out', 100);

wav_freqs = round(logspace(log10(wav_freq_min), log10(wav_freq_max),nfreqs));
ntrials = length(D.trial); 

D_hpf_eltype = D; 



D_multifreq_eltype = cell(nfreqs,1);

normed_pow = cell(1,ntrials); 
for ifreq = 1:nfreqs
  %calculating absolute value envelope at 1Hz (1s chunks)
  cfg=[];
  cfg.out_freq = fs_out;
  cfg.wav_freq = wav_freqs(ifreq);
  cfg.wav_width = wav_width;
  D_multifreq_eltype{ifreq} = bml_envelope_wavpow(cfg, D_hpf_eltype);
  
  nchannels = length(D_multifreq_eltype{ifreq}.label);
  D_multifreq_eltype{ifreq}.med_pow_per_block = NaN(nchannels, ntrials); % initialize
  for itr = 1:ntrials % for each block, normalize by median power
    % rows are channels, so take the median across columns (power at timepoints for each channel)
      D_multifreq_eltype{ifreq}.med_pow_per_block(:,itr) = median(D_multifreq_eltype{ifreq}.trial{itr},2);
      % normalize power by median values within each channel for this block
      %%% normed_pow will be filled with all normed powers across blocks and frequencies; we will average across the 3rd dimension (frequency)
      normed_pow{itr}(:,:,ifreq) = D_multifreq_eltype{ifreq}.trial{itr} ./ D_multifreq_eltype{ifreq}.med_pow_per_block(:,itr);
  end
end

D_hg_eltype = struct; % averaged high gamma
    D_hg_eltype.hdr = D_multifreq_eltype{1}.hdr;
    D_hg_eltype.trial = D_multifreq_eltype{1}.trial;
%     D_hg_eltype.sampleinfo = D_multifreq_eltype{1}.sampleinfo;
    D_hg_eltype.trial = cell(1,ntrials); % to be filled
    D_hg_eltype.time = D_multifreq_eltype{1}.time;
    D_hg_eltype.label = D_multifreq_eltype{1}.label;
    D_hg_eltype.fsample = fs_out; 
% get averaged high gamma
for itr = 1:ntrials
    D_hg_eltype.trial{itr} = mean(normed_pow{itr},3);
end

D_hg =  D_hg_eltype; 





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




% cfg.width        = bml_getopt(cfg,'width',7);
% cfg.gwidth       = bml_getopt(cfg,'gwidth',3);
% cfg.foi          = bml_getopt(cfg,'foi',round(10.^(0.30:0.05:2.4),2,'signif'));
% 
% % dealing with requested times of interest
% dt        = bml_getopt(cfg,'dt',0.020); %width of pixels in returned matrix
% epoch     = bml_raw2annot(data);
% toirange  = [max(epoch.starts), min(epoch.ends)];
% toirange  = round(toirange,9);
% toilim    = bml_getopt(cfg,'toilim',toirange);
% toilim    = round(toilim,9);
% % cfg.toi = (ceil(toilim(1)./dt):1:floor(toilim(2)./dt)).*dt;
% 
% %dealing with times of interest required not to loose data at high
% %frequencies. The time resolution neccesary for the tf analysis depends on
% %the highest frequency used.
% dtsubsampfactor  = ceil((2.*max(cfg.foi)./cfg.width).*dt); %dt sampling factor for high frequencies
% dthf             = dt ./ dtsubsampfactor; %dt required for high frequencie
% cfg.toi = ( (ceil(toirange(1)./dt)*dtsubsampfactor):1:(floor(toirange(2)./dt)*dtsubsampfactor-1) ) .* dthf;
% 
% % calling fieldtrip function 
% cfg.output       = 'pow';
% cfg.method       = 'wavelet';
% cfg.feedback     = 'no';
% cfg.keeptrials   = 'yes';
% cfg.keeptapers   = 'no';
% cfg.pad          = 'nextpow2';
% 
% freq = ft_freqanalysis(cfg, data);
% 
% % checking dimension order
% if ~strcmp(freq.dimord,'rpt_chan_freq_time')
%   error('incorrect dimord')
% end
% 
% % averaging samples in groups of dtsubsampfactor. Sub sampling to dt. 
% s2 = size(freq.time,2);
% m = s2 - mod(s2,dtsubsampfactor);
% tmp = reshape(round(freq.time(1:m),9,'signif'),dtsubsampfactor,[]);
% freq.time = mean(tmp,1);
% 
% s = size(freq.powspctrm);
% tmp = reshape(freq.powspctrm(:,:,:,1:m),s(1),s(2),s(3),dtsubsampfactor,m./dtsubsampfactor);
% freq.powspctrm = squeeze(mean(tmp,4));
% 
% % selecting toilim
% cfg1=[];
% cfg1.latency = toilim;
% freq = ft_selectdata(cfg1,freq);
