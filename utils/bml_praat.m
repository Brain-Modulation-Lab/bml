function bml_praat(varargin)

% BML_PRAAT opens FT_DATATYPE_RAWs in praat
%
% Use as
%   bml_praat(raw1, raw2)
% where raw1, raw2 ... rawN are the FT_DATATYPE_RAWs you wanto to open 
%
% The praat objects will be named r<R>t<T>_<channel_name>, where <R> is the
% index of the FT_DATATYPE_RAW in the call to bml_praat, <T> is the trial 
% number and <channel_name> is the name of the label of the channel
%
% Should open a new praat window
%

% 2017.10.12 AB Tested on Mac OS X 10.12.6

%saving files to temp directory
recycle('off');
tdir=[tempdir 'bml_praat'];

%deleting previous wavs if any
if(exist(tdir,'dir')==7) %7 -> folder
  wavs = dir(fullfile(tdir, '*.wav'));
  for k = 1 : length(wavs)
    delete(fullfile(tdir, wavs(k).name));
  end
else
  mkdir(tdir);
end

%wavs={};
rf=['%0' num2str(ceil(log10(numel(varargin)))+1) 'd']; 
cmd ='';
for i=1:numel(varargin)
  tf=['%0' num2str(ceil(log10(numel(varargin{i}.trial)))+1) 'd']; 
  for t=1:numel(varargin{i}.trial)
    for c=1:numel(varargin{i}.label)
      wfn=char(strrep(varargin{i}.label{c}," ","_"));
      wfn=[tdir filesep 'r' num2str(i,rf) 't' num2str(t,tf) '_' wfn '.wav'];
      v=varargin{i}.trial{t}(c,:);
      audiowrite(wfn,v./max(abs(v)),varargin{i}.fsample);
      %wavs=[wavs,wfn];
      cmd = [cmd wfn ' '];
    end
  end
end


%os specific determination of praat path
if ismac()
  %using open command in mac
  cmd = ['open -a praat ' cmd];
elseif isunix()
  search_dirs={'/usr/local/bin'};
  [~,cmdout]=system('which praat');
  if isempty(cmdout)  
    %cheking for praat in seach_dirs
    indx=find(cellfun(@(x)exist([x filesep 'praat'],'file')==2,search_dirs),1);
    if isempty(indx)
      warning('make sure praat is in your path')    
    else
      setenv('PATH', [search_dirs{indx} ':' getenv('PATH')]);   
    end
  end
  cmd = ['praat --open ' cmd '&'];
else
  cmd = ['praat --open ' cmd '&'];  
  warning('make sure praat is in your path. !echo $PATH')
end

system(cmd);


