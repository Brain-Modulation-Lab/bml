function bml_write_edf(basename, raw)

% BML_WRITE_EDF saves a ft_datatype_raw to EDF file(s). 
%
% Use as
%   bml_write_edf(filename, raw)
%
% basename - string, file basename without extension (trial number will be
%   appended)
% raw - ft_datatype_raw

assert(isstruct(raw),"invalid raw");
assert(all(ismember({'trial','time','label'},fieldnames(raw))),"invalid raw");

nTrial = length(raw.trial);
format_string = strcat(basename,'%0',num2str(ceil(log10(nTrial))),'i.edf');

%creating header
hdr=[];
hdr.nChans = length(raw.label);
hdr.Fs=round(1/mean(diff(raw.time{1})));
hdr.label=raw.label;

for i=1:nTrial
  %calling fieldtrip's EDF writing function 
  ft_write_data(sprintf(format_string,i),raw.trial{i},'header',hdr)
end

