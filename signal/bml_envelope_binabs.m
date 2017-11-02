function env = bml_envelope_binabs(cfg, data)

% BML_ENVELOPE_BINABS Calculate envelope as maximum of abssolute value in
% bins of 'bin_size' points, repeating each value 'repeat' times
%
% Use as
%   env = bml_envelope_binabs(cfg, data)
%
% cfg is a configureation struct with the following fields
% cfg.freq - integer: intended output sampling frequency (default 100Hz)
% cfg.bin_size - integer: size of the bin. If given overwrites cfg.target_fsample
%
% data - FT_DATATYPE_RAW
% 
% Returns a FT_DATATYPE_RAW

DEFAULT_TARGET_FSAMPLE=100;

freq            = bml_getopt(cfg,'freq',DEFAULT_TARGET_FSAMPLE);
bin_size        = bml_getopt(cfg,'bin_size',round(data.fsample/freq));
    
if abs(data.fsample/freq - bin_size) > 0.1
  warning(char(strcat('Specified envelope freq ',num2str(freq),' not possible. Using ',num2str(data.fsample/bin_size))));
end

n_bins=floor(size(data.trial{1},2)./bin_size);
env=struct();
env.trial=cellfun(@(T) reshape(max(...
        reshape(abs(T(:,1:n_bins*bin_size)),[size(T,1), bin_size, n_bins]),...
      [],2),...
    [size(T,1) n_bins]),...
  data.trial,'UniformOutput',false);

env.time=cellfun(@(t) mean(...
    reshape(t(1:n_bins*bin_size),[bin_size, n_bins]),...
    1),...
  data.time,'UniformOutput',false);

env.fsample = data.fsample/bin_size;
env.label = data.label;

env.cfg = struct();
env.cfg.envelope = "binabs";
env.cfg.bin_size = bin_size;
env.cfg.previous = data.cfg;


