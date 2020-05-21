function env = bml_envelope_wavpow(cfg, data)

% BML_ENVELOPE_WAVPOW calculates the power of the signal by wavelet
% decomposition
%
% The envelope is the power of the convolution of the signal with a Morlet
% wavelet.
%
% Use as
%   env = bml_envelope_wavpow(data)
%   env = bml_envelope_wavpow(cfg, data)
%
% cfg is a configuration struct with the following fields
% cfg.out_freq - float: intended output sampling frequency (default 100Hz)
% cfg.wav_freq - float: frequency in hertz of the wavelet
% cfg.wav_width - float: width of the wavelet. (number of cycles in the gaussian)
% cfg.wav_sigma_t - float: sigma parameter of the time domain gaussian
%                   (only used if wav_width is not defined)
% cfg.wav_sigma_f - float: sigma parameter in the frequency domain
%                   (only used if wav_width and wav_sigma_t are not defined)
%
% data - FT_DATATYPE_RAW
% 
% Returns a FT_DATATYPE_RAW


if nargin==1
  data=cfg;
  cfg=[];
end

if ~ismember('fsample',fields(data))
	data.fsample = bml_getFs(data);
end

out_freq = bml_getopt_single(cfg,'out_freq',100);
wav_freq = bml_getopt_single(cfg,'wav_freq',400);
wav_sigma_t = bml_getopt_single(cfg,'wav_sigma_t', 7 ./ (2 .* pi .* wav_freq));
wav_sigma_f = bml_getopt_single(cfg,'wav_sigma_f', 1 ./ (2 .* pi .* wav_sigma_t));
wav_width   = bml_getopt_single(cfg,'wav_width', wav_freq ./ wav_sigma_f);

cfg1=[];
cfg1.fq = wav_freq;
cfg1.width = wav_width;
cfg1.keep_power = 'yes';
cfg1.keep_amp = 'no';
cfg1.downsample = 'average';
cfg1.downsample_freq = out_freq;
env = bml_wavtransform(cfg1,data);
env.trial = env.power;
env = rmfield(env,{'dimord','freq','power'});

env.cfg = struct();
env.cfg.envelope = "wavpow";
env.cfg.wav_freq = wav_freq;
env.cfg.wav_width = wav_width;

if isfield(data,'cfg')
  env.cfg.previous = data.cfg;
end

if ismember('hdr',fieldnames(data))
  env.hdr = data.hdr;
end


