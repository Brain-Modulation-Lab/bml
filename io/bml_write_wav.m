function bml_write_wav(basename, raw)

% BML_WRITE_WAV saves a ft_datatype_raw to a wav file(s). 
%
% Use as
%   bml_write_wav(filename, raw)
%
% basename - string, file basename without extension (trial number will be
%   appended)
% raw - ft_datatype_raw

assert(isstruct(raw),"invalid raw");
assert(all(ismember({'trial','time','label'},fieldnames(raw))),"invalid raw");

for t=1:numel(raw.trial)
    for c=1:numel(raw.label)

      wfn=char(strrep(raw.label{c}," ","_"));
      wfn=[char(basename) 't' num2str(t) '_' wfn '.wav'];
      if ismember({'fsample'},fields(raw))
        Fs = round(raw.fsample,0);
      else
        Fs = round(1/mean(diff(raw.time{1})),0);
      end
      
      v=raw.trial{t}(c,:);
      audiowrite(wfn,v./max(abs(v)),Fs);
    end
end


