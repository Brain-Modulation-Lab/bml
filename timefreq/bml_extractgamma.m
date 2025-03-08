function [D_out] = bml_extractgamma(cfg, D)

cfg.method = bml_getopt(cfg, 'method', 'ft-dpss'); % ft-dpss, bandpass-hilbert, bandpass-bank-hilbert
cfg.fbank_collapse_method = bml_getopt(cfg, 'fbank_collapse_method', 'none'); % pca, median, mean
cfg.fbank_withinband_norm = bml_getopt(cfg, 'fbank_withinband_norm', 'zscore'); % none, mean, median, zscore
cfg.fbank_n = bml_getopt(cfg, 'fbank_n', 1); %
cfg.freq_lowhigh = bml_getopt(cfg, 'freq_lowhigh', [60 150]);
cfg.fs_out = bml_getopt(cfg, 'fs_out', 100); 

fs_in = D.fsample; 

downsample_n = round(fs_in / cfg.fs_out);
if abs((fs_in/cfg.fs_out)-downsample_n)>0.01; error('fs_out should be integer fraction of fs_in'); end


% % construct test matrix to ensure that repmat() indices are computed
% % correctly
% test_nchan = 13; test_ntrial = 21; test_nsamples = 1234;
% test_fsample = 1000; 
% Dtest = []; 
% tmp =  repmat((1:test_nsamples)/test_fsample, [1 test_ntrial]); 
% Dtest.time = mat2cell(tmp, 1, repmat(test_nsamples, [1 test_ntrial])); 
% 
% tmp = 1:(test_nsamples*test_nchan*test_ntrial); % , [test_nchan test_ntrials]); 
% tmp = reshape(tmp, test_nsamples*test_ntrial,  test_nchan); 
% tmp = mat2cell(tmp, repmat(test_nsamples, [test_ntrial 1]), test_nchan);
% Dtest.trial = cellfun(@(x) x', tmp, 'UniformOutput',false); 
% Dtest.trial = Dtest.trial'; 
% Dtest.fsample = 1000; 
% Dtest.label = cellstr("testchan" + string(1:test_nchan))'; 
% D = Dtest; 



% make sure all trials were equal in # samples
assert(all(diff(cellfun(@length, D.time))==0)); 
nchan = length(D.label); ntrial = length(D.trial); 
% dim = strsplit(D.dimord, '_') ; assert(dim{2}=="chan")
% [ntrial, nchan, ntime] = size(D.powspctrm); 


if cfg.method=="ft-dpss"
    if cfg.fbank_n > 1
        freq_c = round(logspace(log10(cfg.freq_lowhigh(1)), log10(cfg.freq_lowhigh(2)), cfg.fbank_n)); 
        freq_bw = diff(freq_c); freq_bw = [freq_bw(1) freq_bw]*3; 
    else 
        freq_c = mean(cfg.freq_lowhigh);
        freq_bw = diff(cfg.freq_lowhigh)/2; 
    end

    cfg1 = []; 
    cfg1.output = 'pow'; 
    cfg1.method = 'mtmconvol'; 
    cfg1.taper = 'dpss'; 
    cfg1.foi = freq_c;
    cfg1.tapsmofrq = freq_bw; 
    cfg1.t_ftimwin = 10 ./ freq_c; % 10 cycles per wavelet
    cfg1.keeptrials = 'yes'; 
    cfg1.pad = 'nextpow2'; 
    cfg1.toi = D.time{1}(1):(1/cfg.fs_out):D.time{1}(end); 
    cfg1.toi = cfg1.toi(10:(end-10));
    D_epoch_gamma = ft_freqanalysis(cfg1, D); 
    
    nsamples_trialwise_ds = length(D_epoch_gamma.time); % the number of samples in each trial after downsampling
    
    X_trialchanfreqtime = D_epoch_gamma.powspctrm;  % rep chan freq time size(X_trialchanfreqtime)
    X_chanfreqtimetrial = permute(X_trialchanfreqtime, [2 3 4 1]); % size(X_chanfreqtrialtime) % chan freq rep time
    X_chanfreqalltime = reshape(X_chanfreqtimetrial, nchan, cfg.fbank_n, []); % all channels

    % make it clear that this has already been downsampled
    X_chanfreqalltime_ds = X_chanfreqalltime; 
    T_alltime_ds = repmat(D_epoch_gamma.time, 1, size(D_epoch_gamma.powspctrm, 1)); 
    assert(size(X_chanfreqalltime_ds, 3)==size(T_alltime_ds, 2)); 

elseif contains(cfg.method, "bandpass") % for all bandpass approaches
%     length(D.time{1})
%     npad = cfg.fs_out - mod(length(D.time{1}), cfg.fs_out); 
    npad = downsample_n - mod(length(D.time{1}), downsample_n); 
       
    X_pad = cellfun(@(x) padarray(x, [0 npad], 0, 'post'), D.trial, 'UniformOutput',false); 
    T_pad = cellfun(@(x) padarray(x, [0 npad], nan, 'post'), D.time, 'UniformOutput',false); 

    X_chanalltime = [X_pad{:}];
    T_alltime = [T_pad{:}]; 

    [~, nsamples_alltime] = size(X_chanalltime); 
    
    if contains(cfg.method, "bank")
        % bandpass-hilbert filters, assuming raw (non-epoched) fieldtrip data
        freq_c = round(logspace(log10(cfg.freq_lowhigh(1)), log10(cfg.freq_lowhigh(2)), cfg.fbank_n));
        freq_bw = diff(freq_c); freq_bw = [freq_bw(1) freq_bw];
    else
        assert(cfg.fbank_n==1, 'cfg.fbank_n must be 1 if method=bandpass-hilbert')
        % single bandpass-hilbert
        freq_c = mean(cfg.freq_lowhigh);
        freq_bw = diff(cfg.freq_lowhigh) / 2;
        cfg.fbank_n = 2; % artificially create a second band to avoid over squeeze() ing
        freq_c = [freq_c freq_c];
        freq_bw = [freq_bw freq_bw];
    end
    
    X_chanfreqalltime = zeros([nchan cfg.fbank_n nsamples_alltime]); 
    for iband=1:cfg.fbank_n
        ul = freq_c(iband) + freq_bw(iband)*[-1 1]; 
        [b, a] = butter(3, ul / (fs_in/2), 'bandpass'); % third order butterworth
        X_bp = filtfilt(b, a, X_chanalltime')'; 
        X_chanfreqalltime(:, iband, :) = abs(hilbert(X_bp'))';
    end

    % downsample via average 
    [~, ~, nsamples] = size(X_chanfreqalltime);
    assert(nsamples==length(T_alltime)); 
%     npad = cfg.fs_out - mod(nsamples, cfg.fs_out); 
%     tmp =  padarray(X_chanfreqalltime, [0 0 npad], nan, 'post');
%     nrem = mod(nsamples, cfg.fs_out); 
%     tmp =  X_chanfreqalltime(:, :, 1:(end-nrem)); 
    tmp =  X_chanfreqalltime;
    tmp = reshape(tmp, nchan, cfg.fbank_n, downsample_n, []);
    X_chanfreqalltime_ds = squeeze(mean(tmp, 3, 'omitnan')); 
    
    tmp = T_alltime; 
%     tmp =  padarray(T_alltime, [0 npad], nan, 'post');
%     tmp =  T_alltime(:, 1:(end-nrem)); 
    tmp = reshape(tmp, downsample_n, []);  
    T_alltime_ds = squeeze(mean(tmp, 1, 'omitnan')); 
    rmidxs = isnan(T_alltime_ds); 

    X_chanfreqalltime_ds = X_chanfreqalltime_ds(:, :, ~rmidxs); % size(X_chanfreqalltime_ds)
    T_alltime_ds = T_alltime_ds(~rmidxs); % size(tmp)

    assert(size(T_alltime_ds, 2)==size(X_chanfreqalltime_ds, 3));

end


% at this point we assume downsampled data
X_chanfreqalltime = X_chanfreqalltime_ds; 
T_alltime = T_alltime_ds; 
if cfg.fbank_withinband_norm=="median"
    med_chanfreq = median(X_chanfreqalltime, 3, 'omitnan'); 
    % med_chanfreqtrialtime = repmat(med_chanfreq, [1 1 ntrial ntime]); size(med_chanfreqtrialtime)
    X_chanfreqalltime_norm = X_chanfreqalltime - med_chanfreq; 
elseif cfg.fbank_withinband_norm=="mean"
    mean_chanfreq = mean(X_chanfreqalltime, 3, 'omitnan'); 
    % med_chanfreqtrialtime = repmat(med_chanfreq, [1 1 ntrial ntime]); size(med_chanfreqtrialtime)
    X_chanfreqalltime_norm = X_chanfreqalltime - mean_chanfreq; 
elseif cfg.fbank_withinband_norm=="zscore"
    mean_chanfreq = mean(X_chanfreqalltime, 3, 'omitnan'); 
    std_chanfreq = std(X_chanfreqalltime, [], 3, 'omitnan'); 

    X_chanfreqalltime_norm = (X_chanfreqalltime - mean_chanfreq) ./ std_chanfreq; 

elseif cfg.fbank_withinband_norm=="none"
    X_chanfreqalltime_norm = X_chanfreqalltime; 
    % nothing
end

method = cfg.fbank_collapse_method; 
if cfg.fbank_n==1; assert(method=="none"); 
elseif cfg.fbank_n > 1;  assert(method~="none");  end
        
if method=="none"
    X_chanalltime = squeeze(X_chanfreqalltime_norm);
elseif method=="median"
    X_chanalltime = squeeze(median(X_chanfreqalltime_norm, 2, 'omitnan'));
elseif method=="mean"
    X_chanalltime = squeeze(mean(X_chanfreqalltime_norm, 2, 'omitnan'));
elseif method=="pca"
    % PCA on the traces
    [~, ~, nsamples] = size(X_chanfreqalltime_norm);
    X_chanalltime = zeros([nchan, nsamples]);
    for ich = 1:nchan
        Xtmp_freqalltime = squeeze(X_chanfreqalltime_norm(ich, :, :));
        [coeff, score, latent] = pca(Xtmp_freqalltime');
        X_chanalltime(ich, :) = score(:,1)';
        % score() * 
    end
end


% reshape and rearrange
X_alltimechan = X_chanalltime'; 
X_timetrialchan = reshape(X_alltimechan, [], ntrial, nchan, 1); % size(tmp)
X_trialchanfreqtime = permute(X_timetrialchan, [2 3 4 1]); 
% inspect aa = squeeze(X_trialchanfreqtime(:, 1, 1, :));
T_trialtime = reshape(T_alltime', [], ntrial)';

assert(~any(any(abs(diff(T_trialtime, [], 1))>0.5)), 'Time axes dont align. At least one trial has a different time vector'); 

D_out = D; 
D_out = rmfield(D_out, 'trial'); 
D_out.time = T_trialtime(1, :); 
D_out.freq = mean(cfg.freq_lowhigh);
D_out.label = D.label; 
D_out.powspctrm = X_trialchanfreqtime; 
D_out.dimord = 'rpt_chan_freq_time';
D_out.fsample = cfg.fs_out;

assert(round(1/mean(diff(D_out.time)))==D_out.fsample); 

ft_checkdata(D_out, 'datatype', 'freq'); 

end




% %% loading electrode type band table
% % if ~exist('el_band','var')
% %   param = readtable([PATH_ART_PROTOCOL, filesep, 'artifact_', ARTIFACT_CRIT , '_params.tsv'],'FileType','text');
% %   param_default = param(param.subject == "default",:);
% %   param_subject = param(strcmp(param.subject,SUBJECT),:);
% %   if ~isempty(param_subject)
% %     param = bml_annot_rowbind(param_default(~ismember(param_default.name,param_subject.name),:),param_subject);
% %   end
% % end
% 
% nfreqs        = bml_getopt(cfg,'nfreqs', 10);
% wav_freq_min  = bml_getopt(cfg,'wav_freq_min',70);
% wav_freq_max  = bml_getopt(cfg,'wav_freq_max',150);
% wav_width  = bml_getopt(cfg,'wav_width', 7);
% fs_out        = bml_getopt(cfg,'fs_out', 100);
% 
% wav_freqs = round(logspace(log10(wav_freq_min), log10(wav_freq_max),nfreqs));
% ntrials = length(D.trial); 
% 
% D_hpf_eltype = D; 
% 
% 
% 
% D_multifreq_eltype = cell(nfreqs,1);
% 
% normed_pow = cell(1,ntrials); 
% for ifreq = 1:nfreqs
%   %calculating absolute value envelope at 1Hz (1s chunks)
%   cfg=[];
%   cfg.out_freq = fs_out;
%   cfg.wav_freq = wav_freqs(ifreq);
%   cfg.wav_width = wav_width;
%   D_multifreq_eltype{ifreq} = bml_envelope_wavpow(cfg, D_hpf_eltype);
%   
%   nchannels = length(D_multifreq_eltype{ifreq}.label);
%   D_multifreq_eltype{ifreq}.med_pow_per_block = NaN(nchannels, ntrials); % initialize
%   for itr = 1:ntrials % for each block, normalize by median power
%     % rows are channels, so take the median across columns (power at timepoints for each channel)
%       D_multifreq_eltype{ifreq}.med_pow_per_block(:,itr) = median(D_multifreq_eltype{ifreq}.trial{itr},2);
%       % normalize power by median values within each channel for this block
%       %%% normed_pow will be filled with all normed powers across blocks and frequencies; we will average across the 3rd dimension (frequency)
%       normed_pow{itr}(:,:,ifreq) = D_multifreq_eltype{ifreq}.trial{itr} ./ D_multifreq_eltype{ifreq}.med_pow_per_block(:,itr);
%   end
% end
% 
% D_hg_eltype = struct; % averaged high gamma
%     D_hg_eltype.hdr = D_multifreq_eltype{1}.hdr;
%     D_hg_eltype.trial = D_multifreq_eltype{1}.trial;
% %     D_hg_eltype.sampleinfo = D_multifreq_eltype{1}.sampleinfo;
%     D_hg_eltype.trial = cell(1,ntrials); % to be filled
%     D_hg_eltype.time = D_multifreq_eltype{1}.time;
%     D_hg_eltype.label = D_multifreq_eltype{1}.label;
%     D_hg_eltype.fsample = fs_out; 
% % get averaged high gamma
% for itr = 1:ntrials
%     D_hg_eltype.trial{itr} = mean(normed_pow{itr},3);
% end
% 
% D_hg =  D_hg_eltype; 











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
