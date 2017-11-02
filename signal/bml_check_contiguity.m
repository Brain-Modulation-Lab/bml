function are_contiguous = bml_check_contiguity(cfg, varargin)

% BML_CHECK_CONTIGUITY returns true if raws are time-contiguous
%
% Use as
%   are_contiguous = bml_check_contiguity(cfg, raw1, raw2, ..., rawN)
%
% cfg.timetol - double: time tolerance in seconds. Defaults to 1e-5
%
% returns true or false

if numel(varargin)<2
  are_contiguous = true;
  return
end

timetol = bml_getopt(cfg, 'timetol', 1e-5);
Fs = nan(1,numel(varargin));
ti = nan(1,numel(varargin));
tf = nan(1,numel(varargin));

for i=1:numel(varargin)
  Fs(i)=varargin{i}.fsample;
  ti(i)=varargin{i}.time{1}(1);
  tf(i)=varargin{i}.time{1}(end);  
end

if length(unique(Fs))>1; error('Different Fs'); end

are_contiguous=all(ti(2:end) - tf(1:(end-1)) - 1/unique(Fs) < timetol);

