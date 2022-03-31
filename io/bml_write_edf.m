function bml_write_edf(filename, raw)

% BML_WRITE_EDF saves a ft_datatype_raw to EDF file(s) and a sync annot
% table
% %%% CHECK THE OUTPUT OF THIS FUNCTION, ft seems to cut long files
% Use as
%   bml_write_edf(filename, raw)
%
% filename - string, file basename without extension (trial number will be
%   appended). The name identifier of the trial (e.g. run, as in BIDs)
%   should be placed at the very end, after an undersocre.
% raw - ft_datatype_raw

assert(isstruct(raw),"invalid raw");
assert(all(ismember({'trial','time','label'},fieldnames(raw))),"invalid raw");

nTrial = length(raw.trial);
format_string = strcat(filename,'%0',num2str(ceil(log10(nTrial))),'i.edf');

%creating header
hdr=[];
hdr.nChans = length(raw.label);
hdr.Fs=round(1/mean(diff(raw.time{1})));
hdr.label=raw.label;

% get fileparts
[path_file,name_file,~] = fileparts(filename);

% create variables for sync table
starts = [];
ends = [];
duration = [];
s1 = [];
t1 = [];
s2 = [];
t2 = [];
folder = [];
name = [];
nSamples = [];
Fs = [];
filetype = [];
nChans = [];
nTrials = [];

for i=1:nTrial
  basename = [name_file, num2str(i)];
  %calling fieldtrip's EDF writing function 
  ft_write_data([filename,  num2str(i), '.edf'],raw.trial{i},'header',hdr)
  % get time
  time = raw.time{i};
  label = raw.label;
  starts = [starts; time(1)];
  ends = [ends; time(end)];
  duration = [duration; time(end)-time(1)];
  s1 = [s1 ; 1];
  t1 = [t1 ; time(1)];
  s2 = [s2 ; length(time)];
  t2 = [t2 ; time(end)];
  folder = [folder ; path_file];
  name = [name ; basename];
  nSamples = [nSamples ; length(time)];
  Fs = [Fs ; raw.fsample];
  filetype = [filetype ; '.edf'];
  nChans = [nChans; length(label)];
  nTrials = [nTrials ; 1];
 
end

% %%%%%%%%%%%%%%%%%
% fix bugs
folder = cellstr(folder);
name = cellstr(name);
filetype = cellstr(filetype);
% %%%%%%%%%%%%%%%%%
% write sync table to save the time information
annot = table(starts, ends, duration, s1, t1, s2, t2, folder, name, nSamples, Fs, filetype, nChans, nTrials);
% find general task name
last_pos = find(name_file == '_', 1, 'last')-1;
name_table = name_file(1:last_pos);
bml_annot_write_tsv(annot, fullfile(path_file, [name_table, '.tsv']));
end
