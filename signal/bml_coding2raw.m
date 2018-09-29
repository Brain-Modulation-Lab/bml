function raw = bml_coding2raw(cfg)

% BML_CODING2RAW creates a raw from the audio in the Coding file
%
% Use as
%   annot = bml_coding2raw(cfg)
%
% cfg.CodingMatPath    - path to mat file with coding info
% cfg.t0               - Time origin of audio file in coding mat file
%
% returns a raw with the audio

if nargin == 1
  CodingMatPath = bml_getopt_single(cfg,'CodingMatPath');
  assert(~isempty(CodingMatPath),'cfg.CodingMatPath required in single argument call');
  load(CodingMatPath,'Audio');
  load(CodingMatPath,'Afs');
else 
  error('Use as bml_codingmatrix2raw(cfg)');
end

t0 = bml_getopt(cfg,'t0',0);

if size(Audio,1) > size(Audio,2)
  Audio = Audio';
end

raw=[];
raw.trial = {Audio};
raw.label = {'CodingAudio'};
raw.time  = {t0 + (1:length(Audio)) ./ Afs};
raw.fsample = Afs;




