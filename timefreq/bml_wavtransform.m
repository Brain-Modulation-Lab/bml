function [Dtf] = bml_wavtransform(cfg, D)
%%
% bml_wavtransform
%   Performs a wavelet transform on timeseries in D.trial. Spectral
%   decomposition is performed trial-wise, and only the amplitude is
%   returned unless the keep_phase flag is 'yes'. If keep_amp is set to
%   'no', amplitude (trial field) is discarded from the output. Dtf is 
%   returned with the same fields as the input D, but the trial field now 
%   contains wavelet amplitudes [time x freq x channel].
%
%   Use as 
%     [Dtf] = bml_wavtransform(cfg, D)
%
% Inputs:
%   D               fieldptrip object containing timeseries to transform.
%   cfg.fq	        vector of frequencies at which to evaluate the wavelet. 
%   cfg.width       vector of wavelet c-parameter for corresponding frequencies in fq
%                   (if length(width)~=length(fq) then width(1) is used for all fq); 
%                   note: std in frequency of a given wavelet=fq/width
%                   (default = 7)
%   cfg.padding     time in seconds at the beginning and end of each trial to
%                   discard to avoid edge artifact.
%   cfg.keep_phase  'yes' to keep phase info.  Will be returned in phase
%                   field (default 'no').
%   cfg.keep_amp    'yes' to keep amplitude info.  Will be returned in trial
%                   field (default 'yes').
%   cfg.keep_power  'yes' to keep the power information. Will be returned
%                   in power field (default 'no')
%   cfg.downsample  indicates if downsample should be applied after wavelet
%                   transformation. 
%                     'average' - returns the mean of consecutive time points
%                                 (only works for power and amplitude)
%                     'filter' - returns one of every n time points
%                     'no' (default) - no downsample applied
%   cfg.downsample_freq  sampling frequency of output wavelet transform
%                   required to be integer division of D.fsample
%                   defaults to closest valid freq to 2*max(cfg.fq)/width

if ~exist('D','var')
    error('bml_wavtransform: cfg variable must contain fieldtrip data object.\n');
end

if isfield(cfg, 'fq')
    fq = cfg.fq;
else
    error('bml_wavtransform: cfg variable must contain a vector of frequencies.\n');
end

if isfield(cfg, 'padding')
    padding = cfg.padding;
else
    padding = 0;
end

if isfield(cfg, 'keep_phase')
    if strcmp(cfg.keep_phase,'yes') || istrue(cfg.keep_phase)
        keep_phase = true;
    else
        keep_phase = false;
    end
else
    keep_phase = false;
end
if isfield(cfg, 'keep_amp')
    if strcmp(cfg.keep_amp,'yes') || istrue(cfg.keep_amp)
        keep_amp = true;
    else
        keep_amp = false;
    end
else
    keep_amp = true;
end
keep_power = bml_getopt_single(cfg,'keep_power',0);

if isfield(cfg, 'width')
    width = cfg.width;
else
    width = 7;
end
if ~isfield(D, 'fsample')
  D.fsample = bml_getFs(D); 
end

%dealing with downsample frequency
[max_fq, max_fq_i] = max(fq);
if length(width)==1
  max_fq_width = width;
elseif length(width) == length(fq)
  max_fq_width = width(max_fq_i);
else
  error('length of width should be 1 or equal to length of fq');
end
downsample_freq = 2.*max_fq/max_fq_width; %default downsample freq
downsample_freq = bml_getopt(cfg,'downsample_freq',downsample_freq);
downsample_factor = round(D.fsample/downsample_freq);
downsample_freq = D.fsample/downsample_factor;

ds = bml_getopt_single(cfg,'downsample','no');
if ismember(ds,{'average'}) && keep_phase
  error('cannot keep phases and downsample with the average method');
end

%iterating through trials
Dtf = D;
npad = round(D.fsample*padding);
Dtf.freq = fq;
%Dtf.dimord = 'time_freq_channel';
Dtf.dimord = 'channel_time_freq';
Dtf.trial = {};
for tr = 1:length(D.trial)
    fprintf('bml_wavtransform: trial %d\n', tr);
    %     % pre-allocate trial
    %     Dtf.trial{tr} = zeros([size(D.trial{tr},2), ...
    %         length(fq), ...
    %         size(D.trial{tr},1)]);
    wavdata = fast_wavtransform(fq,D.trial{tr},D.fsample,width); 
    %default dimorder 'time_freq_channel'
    %wanted dimorder 'channel_time_freq'
    wavdata = permute(wavdata, [3,1,2]);
    
    if keep_amp
        Dtf.trial{tr} = abs(wavdata(:,(npad+1):(end-npad),:));
    end
    if keep_phase
        Dtf.phase{tr} = angle(wavdata(:,(npad+1):(end-npad),:));
    end
    if keep_power
        Dtf.power{tr} = abs(wavdata(:,(npad+1):(end-npad),:)).^2;
    end
    Dtf.time{tr} = Dtf.time{tr}((npad+1):(end-npad));
    
    %dealing with downsample
    if ismember(ds, {'average','filter'})
      %calculating time label of new time samples
      s1 = length(Dtf.time{tr});
      m = s1 - mod(s1,downsample_factor);
      Dtf.time{tr} = mean(reshape(round(Dtf.time{tr}(1:m),9,'signif'),downsample_factor,[]),1);
      
      %dealing with downsampling using the average method
      if strcmp(ds, 'average')
        if keep_amp         
          s = size(Dtf.trial{tr});
          if length(s) == 2; s = [s,1]; end
          Dtf.trial{tr} = squeeze(mean(reshape(Dtf.trial{tr}(:,1:m,:),s(1),downsample_factor,m./downsample_factor,s(3)),2));
        end
        if keep_power        
          s = size(Dtf.power{tr});
          if length(s) == 2; s = [s,1]; end
          Dtf.power{tr} = squeeze(mean(reshape(Dtf.power{tr}(:,1:m,:),s(1),downsample_factor,m./downsample_factor,s(3)),2));
        end
      elseif strcmp(ds, 'filter')
        stop('method downsample filter not implemented')
      elseif ~strcmp(ds, 'no')
        stop('unknown downsample method')
      end
    end
end

if ismember(ds, {'average','filter'})
  fprintf('downsample to %f using the %s method \n',round(downsample_freq,1),ds);
  Dtf.fsample = downsample_freq;
end

