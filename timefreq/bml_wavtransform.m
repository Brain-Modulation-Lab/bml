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
%   
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
    if strcmp(cfg.keep_phase,'yes') || cfg.keep_phase
        keep_phase = true;
    end
else
    keep_phase = false;
end
if isfield(cfg, 'keep_amp')
    if strcmp(cfg.keep_amp,'yes') || cfg.keep_amp
        keep_amp = true;
    end
else
    keep_amp = true;
end
if isfield(cfg, 'width')
    width = cfg.width;
else
    width = 7;
end
Dtf = D;
npad = round(D.fsample*padding);
Dtf.freq = fq;
Dtf.dimord = 'time_freq_channel';
Dtf.trial = {};
for tr = 1:length(D.trial)
    fprintf('bml_wavtransform: trial %d\n', tr);
    %     % pre-allocate trial
    %     Dtf.trial{tr} = zeros([size(D.trial{tr},2), ...
    %         length(fq), ...
    %         size(D.trial{tr},1)]);
    wavdata = fast_wavtransform(fq,D.trial{tr},D.fsample,width);
    if keep_amp
        Dtf.trial{tr} = abs(wavdata((npad+1):(end-npad),:,:));
    end
    if keep_phase
        Dtf.phase{tr} = angle(wavdata((npad+1):(end-npad),:,:));
    end
    Dtf.time{tr} = Dtf.time{tr}((npad+1):(end-npad));
end

end

